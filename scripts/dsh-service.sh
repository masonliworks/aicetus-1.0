#!/usr/bin/env bash
# DSH Web 服务管理脚本 —— 用 macOS launchd 把 dsh web 变成开机自启的后台服务
#
# 用法:
#   ./dsh-service.sh install   安装 LaunchAgent 并立即加载 (推荐)
#   ./dsh-service.sh status    查看服务状态
#   ./dsh-service.sh kickstart 立即重启服务 (杀掉旧实例并拉起新的)
#   ./dsh-service.sh stop      停止服务 (launchctl bootout)
#   ./dsh-service.sh logs      查看服务日志 (tail -f)
#   ./dsh-service.sh uninstall 卸载并移除 plist
#
# 原理: 服务由 launchd 托管, 不依赖任何终端窗口;
#       登录后自动启动, 进程退出后自动重启 (KeepAlive)。
set -euo pipefail

LABEL="com.dsh.web"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/$LABEL.plist"
LOG_DIR="$HOME/.dsh/logs"
DSH_BIN="/Users/lifengzhi/.local/bin/dsh"
NODE_DIR="/Users/lifengzhi/.local/bin"

write_plist() {
  mkdir -p "$PLIST_DIR" "$LOG_DIR"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$DSH_BIN</string>
        <string>web</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$HOME</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
        <key>PATH</key>
        <string>$NODE_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>

    <!-- 登录时自动启动; 退出后自动重启(崩溃/被杀都拉起) -->
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <!-- 重启间隔, 防止端口被占时疯狂重试 -->
    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>ProcessType</key>
    <string>Background</string>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/dsh-web.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/dsh-web.stderr.log</string>
</dict>
</plist>
EOF
  echo "plist 已写入: $PLIST"
}

install() {
  write_plist
  # 先卸载旧的同名服务(忽略不存在), 再加载
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "已加载 launchd 服务: $LABEL"
  echo
  echo "提示: 如果 3080 端口仍被旧的终端进程占用, 服务会每 10 秒重试;"
  echo "      关掉原来启动 dsh 的终端窗口后, launchd 会在几秒内自动接管。"
  echo "      访问地址不变: http://127.0.0.1:3080"
}

status() {
  launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state|pid|last exit|program|runs" | head -12
  echo "--- 端口 ---"
  lsof -nP -iTCP:3080 -sTCP:LISTEN 2>/dev/null || echo "(3080 无监听)"
}

kickstart() {
  # 重启由 launchd 管理的服务; 若旧终端进程还占着端口, 请先关掉它
  launchctl kickstart -k "gui/$(id -u)/$LABEL"
  echo "已请求重启 $LABEL"
  sleep 2
  status
}

stop() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "已停止 $LABEL" || echo "服务未在运行"
}

uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "已卸载 $LABEL, 并删除 $PLIST"
}

case "${1:-}" in
  install)   install ;;
  status)    status ;;
  kickstart) kickstart ;;
  stop)      stop ;;
  logs)      tail -f "$LOG_DIR/dsh-web.stderr.log" "$LOG_DIR/dsh-web.stdout.log" ;;
  uninstall) uninstall ;;
  *) echo "用法: $0 {install|status|kickstart|stop|logs|uninstall}"; exit 1 ;;
esac
