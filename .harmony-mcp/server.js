const readline = require('readline');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const rl = readline.createInterface({ input: process.stdin });

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function sendError(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

function sendResult(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function safeResolve(filePath) {
  const resolved = path.resolve(PROJECT_ROOT, filePath);
  if (!resolved.startsWith(PROJECT_ROOT)) {
    throw new Error('Path traversal denied');
  }
  return resolved;
}

rl.on('line', (line) => {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = msg;

  if (method === 'initialize') {
    sendResult(id, {
      protocolVersion: params?.protocolVersion || '2024-11-05',
      capabilities: { tools: {} },
      serverInfo: { name: 'harmony-mcp', version: '1.0.0' }
    });

  } else if (method === 'tools/list') {
    sendResult(id, {
      tools: [
        {
          name: 'read_file',
          description: 'Read a file from the project',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Relative path from project root (e.g. entry/src/main/ets/pages/Index.ets)' }
            },
            required: ['path']
          }
        },
        {
          name: 'write_file',
          description: 'Write content to a file (creates dirs if needed)',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Relative path from project root' },
              content: { type: 'string', description: 'File content to write' }
            },
            required: ['path', 'content']
          }
        },
        {
          name: 'search_files',
          description: 'Search for text in project files using ripgrep or findstr',
          inputSchema: {
            type: 'object',
            properties: {
              pattern: { type: 'string', description: 'Search pattern' },
              glob: { type: 'string', description: 'File pattern filter (e.g. *.ets, *.ts)' }
            },
            required: ['pattern']
          }
        },
        {
          name: 'project_tree',
          description: 'Show project directory structure (up to depth 3)',
          inputSchema: {
            type: 'object',
            properties: {
              dir: { type: 'string', description: 'Relative subdirectory (optional)' },
              depth: { type: 'number', description: 'Depth level (default 2, max 4)' }
            }
          }
        },
        {
          name: 'run_shell',
          description: 'Run a shell command in the project directory',
          inputSchema: {
            type: 'object',
            properties: {
              command: { type: 'string', description: 'Shell command to run' }
            },
            required: ['command']
          }
        },
        {
          name: 'scan_ai_markers',
          description: 'Scan project source files for // AI: markers and return details',
          inputSchema: {
            type: 'object',
            properties: {
              dir: { type: 'string', description: 'Subdirectory to scan (optional, default is root)' }
            }
          }
        }
      ]
    });

  } else if (method === 'tools/call') {
    const toolName = params?.name;
    const args = params?.arguments || {};

    try {
      switch (toolName) {
        case 'read_file': {
          const filePath = safeResolve(args.path);
          const content = fs.readFileSync(filePath, 'utf-8');
          sendResult(id, { content: [{ type: 'text', text: content }] });
          break;
        }
        case 'write_file': {
          const filePath = safeResolve(args.path);
          fs.mkdirSync(path.dirname(filePath), { recursive: true });
          fs.writeFileSync(filePath, args.content, 'utf-8');
          sendResult(id, { content: [{ type: 'text', text: 'Written ' + args.path }] });
          break;
        }
        case 'search_files': {
          const cwd = PROJECT_ROOT;
          const glob = args.glob || '*';
          let result;
          try {
            result = execSync(
              'rg --no-heading -n "' + args.pattern.replace(/"/g, '\\"') + '" -g "' + glob + '"',
              { cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 10000 }
            );
          } catch {
            try {
              result = execSync(
                'Get-ChildItem -Recurse -Filter "' + glob + '" | Select-String -Pattern "' + args.pattern + '"',
                { cwd, encoding: 'utf-8', shell: 'powershell', stdio: ['pipe', 'pipe', 'pipe'], timeout: 15000 }
              );
            } catch (e2) {
              result = e2.stdout || 'No matches found';
            }
          }
          sendResult(id, { content: [{ type: 'text', text: result }] });
          break;
        }
        case 'project_tree': {
          const targetDir = safeResolve(args.dir || '.');
          const depth = Math.min(args.depth || 2, 4);
          function tree(dir, level) {
            if (level > depth) return '';
            let lines = '';
            const items = fs.readdirSync(dir, { withFileTypes: true })
              .filter(function(d) { return !d.name.startsWith('.') && d.name !== 'node_modules' && d.name !== 'oh_modules'; });
            for (const item of items) {
              const indent = '  '.repeat(level);
              const prefix = item.isDirectory() ? '[DIR]' : '[FILE]';
              lines += indent + prefix + ' ' + item.name + '\n';
              if (item.isDirectory()) {
                lines += tree(path.join(dir, item.name), level + 1);
              }
            }
            return lines;
          }
          const output = tree(targetDir, 0);
          sendResult(id, { content: [{ type: 'text', text: output || '(empty)' }] });
          break;
        }
        case 'run_shell': {
          try {
            const result = execSync(args.command, {
              cwd: PROJECT_ROOT,
              encoding: 'utf-8',
              timeout: 30000,
              shell: 'powershell'
            });
            sendResult(id, { content: [{ type: 'text', text: result || '(no output)' }] });
          } catch (e) {
            const stderr = e.stderr || '';
            const stdout = e.stdout || '';
            sendResult(id, { content: [{ type: 'text', text: stdout + '\n' + stderr }] });
          }
          break;
        }
        case 'scan_ai_markers': {
          const targetDir = safeResolve(args.dir || '.');
          const results = [];
          function walk(dir) {
            let items;
            try { items = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
            for (const item of items) {
              const full = path.join(dir, item.name);
              if (item.isDirectory()) {
                if (!item.name.startsWith('.') && item.name !== 'oh_modules' && item.name !== 'node_modules' && item.name !== 'build') {
                  walk(full);
                }
              } else if (item.name.endsWith('.ets') || item.name.endsWith('.ts') || item.name.endsWith('.js') || item.name.endsWith('.json5')) {
                try {
                  const content = fs.readFileSync(full, 'utf-8');
                  const lines = content.split('\n');
                  for (let i = 0; i < lines.length; i++) {
                    const trimmed = lines[i].trim();
                    const idx = trimmed.indexOf('// AI:');
                    if (idx !== -1) {
                      const relPath = path.relative(PROJECT_ROOT, full);
                      const before = lines[Math.max(0, i - 2)].trim();
                      const after = lines[Math.min(lines.length - 1, i + 2)].trim();
                      results.push({
                        file: relPath,
                        line: i + 1,
                        marker: trimmed.substring(idx).trim(),
                        context: { before: before, after: after }
                      });
                    }
                  }
                } catch { }
              }
            }
          }
          walk(targetDir);
          const text = results.length === 0
            ? 'No // AI: markers found.'
            : JSON.stringify(results, null, 2);
          sendResult(id, { content: [{ type: 'text', text: text }] });
          break;
        }
        default:
          sendError(id, -32601, 'Unknown tool: ' + toolName);
      }
    } catch (e) {
      sendError(id, -32603, e.message);
    }

  } else if (method === 'notifications/initialized') {
    // ignore
  } else if (method === 'ping') {
    sendResult(id, {});
  }
});

send({ jsonrpc: '2.0', method: 'initialized' });
