#!/usr/bin/env node
/**
 * PUNK CLI - 本地端
 * 运行在开发者电脑上，桥接 Claude Code 进程 和 中继服务器
 * 
 * 用法:
 *   punk connect              # 连接到中继服务器
 *   punk pair                 # 生成配对码
 *   punk status               # 查看当前状态
 */

const WebSocket = require('ws');
const { spawn } = require('child_process');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const CONFIG_FILE = path.join(process.env.HOME || '~', '.punk', 'config.json');
const RELAY_URL = process.env.PUNK_RELAY || 'ws://localhost:3001';
const API_URL = process.env.PUNK_API || 'http://localhost:3001';

// ── 配置管理 ──────────────────────────────────────────────────────────────────
function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    }
  } catch {}
  return {};
}

function saveConfig(config) {
  const dir = path.dirname(CONFIG_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

// ── API 调用 ──────────────────────────────────────────────────────────────────
function apiPost(endpoint, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const url = new URL(API_URL + endpoint);
    const mod = url.protocol === 'https:' ? https : http;
    const req = mod.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': data.length },
    }, res => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => resolve(JSON.parse(body)));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// ── Claude Code 会话管理 ──────────────────────────────────────────────────────
class ClaudeCodeSession {
  constructor(id, ws) {
    this.id = id;
    this.ws = ws; // 到中继服务器的 WebSocket
    this.process = null;
    this.mode = 'ask'; // plan | ask | auto | dangerous
    this.title = `Session ${id.substring(0, 6)}`;
    this.status = 'idle';
    this.pendingPermissions = new Map();
  }

  start(workDir = process.cwd()) {
    // 启动 claude 进程（使用 --output-format stream-json 获取结构化输出）
    const args = ['--output-format', 'stream-json', '--print'];
    if (this.mode === 'auto') args.push('--dangerously-skip-permissions');

    this.process = spawn('claude', args, {
      cwd: workDir,
      env: { ...process.env },
    });

    this.status = 'running';
    this._reportStatus();

    this.process.stdout.on('data', (data) => {
      const text = data.toString();
      // 解析流式 JSON 输出
      text.split('\n').filter(Boolean).forEach(line => {
        try {
          const event = JSON.parse(line);
          this._handleClaudeEvent(event);
        } catch {
          // 非 JSON 输出直接转发
          this._sendOutput(text);
        }
      });
    });

    this.process.stderr.on('data', (data) => {
      this._sendOutput(data.toString(), 'stderr');
    });

    this.process.on('exit', (code) => {
      this.status = 'idle';
      this._reportStatus();
    });
  }

  sendPrompt(text) {
    if (!this.process || this.process.exitCode !== null) {
      this.start();
    }
    this.process.stdin.write(text + '\n');
    this.status = 'running';
    this._reportStatus();
  }

  _handleClaudeEvent(event) {
    switch (event.type) {
      case 'assistant':
        this._sendOutput(event.message?.content?.[0]?.text || '');
        break;

      case 'tool_use':
        // 工具调用 → 权限审批
        if (this.mode === 'auto' || this.mode === 'dangerous') {
          // 自动批准
          this._approvePermission(event.id, true);
        } else if (this.mode === 'plan') {
          // 计划模式：总是拒绝实际执行
          this._approvePermission(event.id, false);
        } else {
          // ask 模式：推送给手机等待审批
          this._requestPermission(event.id, event.name, event.input);
        }
        break;

      case 'result':
        this.status = 'idle';
        this._reportStatus();
        break;
    }
  }

  _requestPermission(permissionId, tool, args) {
    this.pendingPermissions.set(permissionId, { tool, args });
    this.ws.send(JSON.stringify({
      type: 'permission_request',
      sessionId: this.id,
      permissionId,
      tool,
      description: `${tool}: ${JSON.stringify(args).substring(0, 100)}`,
      args,
    }));
  }

  _approvePermission(permissionId, approved) {
    this.pendingPermissions.delete(permissionId);
    // Claude Code 通过 stdin 接收 y/n
    if (this.process) {
      this.process.stdin.write(approved ? 'y\n' : 'n\n');
    }
  }

  handlePermissionResponse(permissionId, approved) {
    this._approvePermission(permissionId, approved);
  }

  abort() {
    this.process?.kill('SIGINT');
    this.status = 'idle';
    this._reportStatus();
  }

  setMode(mode) {
    this.mode = mode;
    this._reportStatus();
  }

  _sendOutput(text, stream = 'stdout') {
    this.ws.send(JSON.stringify({
      type: 'output',
      sessionId: this.id,
      data: text,
      stream,
    }));
  }

  _reportStatus() {
    this.ws.send(JSON.stringify({
      type: 'session_update',
      session: {
        id: this.id,
        title: this.title,
        status: this.status,
        mode: this.mode,
        pendingPermissions: [...this.pendingPermissions.keys()].length,
      },
    }));
  }
}

// ── 主连接逻辑 ────────────────────────────────────────────────────────────────
async function connect() {
  let config = loadConfig();

  // 首次运行：配对
  if (!config.token) {
    console.log('🔑 首次运行，正在获取配对码...');
    const result = await apiPost('/api/pair', {});
    config = { ...config, ...result };
    saveConfig(config);
    console.log(`\n📱 请在 PUNK App 中输入配对码：\n\n   ╔════════╗\n   ║  ${result.pairCode}  ║\n   ╚════════╝\n`);
  }

  const ws = new WebSocket(`${RELAY_URL}?token=${config.token}&role=cli`);
  const claudeSessions = new Map();

  ws.on('open', () => {
    console.log('✅ 已连接到 PUNK 中继服务器');
    console.log('📱 等待手机连接...');
  });

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      handleRelayMessage(ws, claudeSessions, msg, config);
    } catch (e) {
      console.error('消息解析错误:', e);
    }
  });

  ws.on('close', (code, reason) => {
    console.log(`⚠️  连接断开 (${code}): ${reason}`);
    console.log('5秒后重连...');
    setTimeout(connect, 5000);
  });

  ws.on('error', (err) => {
    console.error('连接错误:', err.message);
  });
}

function handleRelayMessage(ws, sessions, msg, config) {
  switch (msg.type) {
    case 'prompt': {
      let session = sessions.get(msg.sessionId);
      if (!session) {
        session = new ClaudeCodeSession(msg.sessionId || require('crypto').randomUUID(), ws);
        sessions.set(session.id, session);
      }
      session.sendPrompt(msg.text);
      break;
    }

    case 'new_session': {
      const id = require('crypto').randomUUID();
      const session = new ClaudeCodeSession(id, ws);
      sessions.set(id, session);
      ws.send(JSON.stringify({ type: 'session_update', session: { id, status: 'idle', mode: 'ask' } }));
      break;
    }

    case 'permission_response': {
      const session = sessions.get(msg.sessionId);
      session?.handlePermissionResponse(msg.permissionId, msg.approved);
      break;
    }

    case 'set_mode': {
      const session = sessions.get(msg.sessionId);
      session?.setMode(msg.mode);
      break;
    }

    case 'abort': {
      const session = sessions.get(msg.sessionId);
      session?.abort();
      break;
    }

    case 'connected':
      console.log('✅ 握手成功，设备 ID:', msg.deviceId);
      // 上报已有会话
      ws.send(JSON.stringify({
        type: 'session_list',
        sessions: [...sessions.values()].map(s => ({
          id: s.id, title: s.title, status: s.status, mode: s.mode,
        })),
      }));
      break;
  }
}

// ── 命令行入口 ────────────────────────────────────────────────────────────────
const command = process.argv[2] || 'connect';

switch (command) {
  case 'connect':
    connect().catch(console.error);
    break;

  case 'status':
    const cfg = loadConfig();
    if (!cfg.deviceId) {
      console.log('未配对，请先运行: punk connect');
    } else {
      console.log('设备 ID:', cfg.deviceId);
      console.log('配对码:', cfg.pairCode);
      console.log('中继服务器:', RELAY_URL);
    }
    break;

  case 'reset':
    fs.existsSync(CONFIG_FILE) && fs.unlinkSync(CONFIG_FILE);
    console.log('配置已重置');
    break;

  default:
    console.log('用法: punk [connect|status|reset]');
}
