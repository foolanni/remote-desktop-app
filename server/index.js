/**
 * PUNK 中继服务器
 * 
 * 架构：手机 App ←→ Relay Server ←→ 本地 CLI (Claude Code)
 * - 手机连接 /phone WebSocket
 * - 本地 CLI 连接 /cli WebSocket  
 * - 消息在两端之间中继，服务器不持久化任何数据
 */

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const JWT_SECRET = process.env.JWT_SECRET || 'punk-relay-secret-change-in-prod';
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// 存储设备配对信息（内存，不持久化）
const devices = new Map(); // deviceId -> { cliWs, phoneWs[], sessions }
const sessions = new Map(); // sessionId -> { deviceId, status, messages[] }

// ── REST API ──────────────────────────────────────────────────────────────────

// 生成配对 token（CLI 调用）
app.post('/api/pair', (req, res) => {
  const deviceId = uuidv4();
  const pairCode = Math.random().toString(36).substring(2, 8).toUpperCase();
  const token = jwt.sign({ deviceId, role: 'cli' }, JWT_SECRET, { expiresIn: '30d' });
  
  devices.set(deviceId, {
    deviceId,
    pairCode,
    token,
    cliWs: null,
    phoneWsSet: new Set(),
    sessions: new Map(),
    connectedAt: null,
    lastSeen: null,
  });

  res.json({ deviceId, pairCode, token });
  console.log(`[PAIR] New device: ${deviceId}, code: ${pairCode}`);
});

// 手机扫码后验证配对码
app.post('/api/pair/verify', (req, res) => {
  const { pairCode } = req.body;
  const device = [...devices.values()].find(d => d.pairCode === pairCode?.toUpperCase());
  
  if (!device) {
    return res.status(404).json({ error: 'Invalid pair code' });
  }

  const phoneToken = jwt.sign(
    { deviceId: device.deviceId, role: 'phone' },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  res.json({
    deviceId: device.deviceId,
    token: phoneToken,
    deviceName: `Device-${device.deviceId.substring(0, 6)}`,
  });
  console.log(`[PAIR] Phone paired to device: ${device.deviceId}`);
});

// 获取设备状态
app.get('/api/devices/:deviceId/status', authMiddleware, (req, res) => {
  const device = devices.get(req.params.deviceId);
  if (!device) return res.status(404).json({ error: 'Device not found' });

  res.json({
    deviceId: device.deviceId,
    online: device.cliWs?.readyState === WebSocket.OPEN,
    lastSeen: device.lastSeen,
    sessionCount: device.sessions.size,
    phoneCount: device.phoneWsSet.size,
  });
});

// 获取所有会话列表
app.get('/api/devices/:deviceId/sessions', authMiddleware, (req, res) => {
  const device = devices.get(req.params.deviceId);
  if (!device) return res.status(404).json({ error: 'Device not found' });

  const sessionList = [...device.sessions.values()].map(s => ({
    id: s.id,
    title: s.title || `Session ${s.id.substring(0, 6)}`,
    status: s.status,
    mode: s.mode,
    createdAt: s.createdAt,
    lastActivity: s.lastActivity,
    pendingPermissions: s.pendingPermissions?.length || 0,
  }));

  res.json(sessionList);
});

function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.auth = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// ── WebSocket 服务器 ──────────────────────────────────────────────────────────

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'ws://localhost');
  const token = url.searchParams.get('token');
  const role = url.searchParams.get('role'); // 'cli' or 'phone'

  let auth;
  try {
    auth = jwt.verify(token, JWT_SECRET);
  } catch {
    ws.send(JSON.stringify({ type: 'error', message: 'Invalid token' }));
    ws.close(4001, 'Invalid token');
    return;
  }

  const { deviceId } = auth;
  const device = devices.get(deviceId);
  if (!device) {
    ws.send(JSON.stringify({ type: 'error', message: 'Device not found' }));
    ws.close(4004, 'Device not found');
    return;
  }

  if (role === 'cli' || auth.role === 'cli') {
    handleCliConnection(ws, device);
  } else {
    handlePhoneConnection(ws, device);
  }
});

function handleCliConnection(ws, device) {
  device.cliWs = ws;
  device.connectedAt = new Date();
  device.lastSeen = new Date();

  console.log(`[CLI] Connected: ${device.deviceId}`);
  ws.send(JSON.stringify({ type: 'connected', role: 'cli', deviceId: device.deviceId }));

  // 通知所有已连接的手机
  broadcastToPhones(device, { type: 'cli_online', deviceId: device.deviceId });

  ws.on('message', (data) => {
    device.lastSeen = new Date();
    try {
      const msg = JSON.parse(data);
      handleCliMessage(device, msg);
    } catch (e) {
      console.error('[CLI] Parse error:', e);
    }
  });

  ws.on('close', () => {
    device.cliWs = null;
    device.lastSeen = new Date();
    broadcastToPhones(device, { type: 'cli_offline', deviceId: device.deviceId });
    console.log(`[CLI] Disconnected: ${device.deviceId}`);
  });
}

function handlePhoneConnection(ws, device) {
  device.phoneWsSet.add(ws);
  console.log(`[PHONE] Connected: ${device.deviceId}, total: ${device.phoneWsSet.size}`);
  
  ws.send(JSON.stringify({
    type: 'connected',
    role: 'phone',
    deviceId: device.deviceId,
    cliOnline: device.cliWs?.readyState === WebSocket.OPEN,
  }));

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      handlePhoneMessage(device, ws, msg);
    } catch (e) {
      console.error('[PHONE] Parse error:', e);
    }
  });

  ws.on('close', () => {
    device.phoneWsSet.delete(ws);
    console.log(`[PHONE] Disconnected: ${device.deviceId}, remaining: ${device.phoneWsSet.size}`);
  });
}

function handleCliMessage(device, msg) {
  switch (msg.type) {
    case 'session_update':
      updateSession(device, msg.session);
      broadcastToPhones(device, { type: 'session_update', session: msg.session });
      break;

    case 'output':
      broadcastToPhones(device, { type: 'output', sessionId: msg.sessionId, data: msg.data });
      break;

    case 'permission_request':
      // Claude Code 请求权限，推送给手机
      const session = device.sessions.get(msg.sessionId);
      if (session) {
        if (!session.pendingPermissions) session.pendingPermissions = [];
        session.pendingPermissions.push({
          id: uuidv4(),
          tool: msg.tool,
          description: msg.description,
          args: msg.args,
          requestedAt: new Date(),
        });
      }
      broadcastToPhones(device, {
        type: 'permission_request',
        sessionId: msg.sessionId,
        permissionId: msg.permissionId,
        tool: msg.tool,
        description: msg.description,
        args: msg.args,
      });
      break;

    case 'session_list':
      // CLI 上报当前所有会话
      msg.sessions.forEach(s => updateSession(device, s));
      broadcastToPhones(device, { type: 'session_list', sessions: msg.sessions });
      break;

    default:
      broadcastToPhones(device, msg);
  }
}

function handlePhoneMessage(device, phoneWs, msg) {
  const cliWs = device.cliWs;
  
  switch (msg.type) {
    case 'send_prompt':
      // 手机发送指令给 Claude Code
      forwardToCli(cliWs, { type: 'prompt', sessionId: msg.sessionId, text: msg.text });
      break;

    case 'permission_response':
      // 手机审批或拒绝权限
      const session = device.sessions.get(msg.sessionId);
      if (session?.pendingPermissions) {
        session.pendingPermissions = session.pendingPermissions.filter(
          p => p.id !== msg.permissionId
        );
      }
      forwardToCli(cliWs, {
        type: 'permission_response',
        sessionId: msg.sessionId,
        permissionId: msg.permissionId,
        approved: msg.approved,
      });
      break;

    case 'set_mode':
      // 设置执行模式: plan | ask | auto | dangerous
      forwardToCli(cliWs, { type: 'set_mode', sessionId: msg.sessionId, mode: msg.mode });
      break;

    case 'new_session':
      forwardToCli(cliWs, { type: 'new_session' });
      break;

    case 'abort_session':
      forwardToCli(cliWs, { type: 'abort', sessionId: msg.sessionId });
      break;

    default:
      forwardToCli(cliWs, msg);
  }
}

function forwardToCli(cliWs, msg) {
  if (cliWs?.readyState === WebSocket.OPEN) {
    cliWs.send(JSON.stringify(msg));
  }
}

function broadcastToPhones(device, msg) {
  const data = JSON.stringify(msg);
  device.phoneWsSet.forEach(ws => {
    if (ws.readyState === WebSocket.OPEN) ws.send(data);
  });
}

function updateSession(device, sessionData) {
  const existing = device.sessions.get(sessionData.id) || {};
  device.sessions.set(sessionData.id, {
    ...existing,
    ...sessionData,
    lastActivity: new Date(),
  });
}

// ── 健康检查 ──────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    devices: devices.size,
    uptime: process.uptime(),
  });
});

server.listen(PORT, () => {
  console.log(`🚀 PUNK Relay Server running on port ${PORT}`);
  console.log(`   WebSocket: ws://localhost:${PORT}`);
  console.log(`   HTTP API:  http://localhost:${PORT}/api`);
});

module.exports = { app, server };
