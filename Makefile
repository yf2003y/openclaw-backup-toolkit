.PHONY: install uninstall test clean help

# 默认安装目录
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin

# 脚本文件
SCRIPTS = scripts/backup.sh scripts/restore.sh scripts/start.sh

help:
	@echo "OpenClaw Backup Toolkit - Makefile"
	@echo ""
	@echo "使用方法:"
	@echo "  make install     安装工具包"
	@echo "  make uninstall   卸载工具包"
	@echo "  make test        运行测试"
	@echo "  make clean       清理临时文件"
	@echo "  make help        显示帮助"
	@echo ""
	@echo "自定义安装目录:"
	@echo "  make install PREFIX=/usr/local"

install:
	@echo "Installing OpenClaw Backup Toolkit..."
	@mkdir -p $(BINDIR)
	@cp $(SCRIPTS) $(BINDIR)/
	@for script in $(SCRIPTS); do \
		name=$$(basename $$script); \
		chmod +x $(BINDIR)/$$name; \
		echo "  Installed: $$name"; \
	done
	@echo ""
	@echo "Installation complete!"
	@echo "Scripts installed to: $(BINDIR)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run '$(BINDIR)/install.sh' to configure"
	@echo "  2. Or manually create ~/.openclaw-backup.conf"

uninstall:
	@echo "Uninstalling OpenClaw Backup Toolkit..."
	@for script in $(SCRIPTS); do \
		name=$$(basename $$script); \
		rm -f $(BINDIR)/$$name; \
		echo "  Removed: $$name"; \
	done
	@echo "Uninstall complete!"

test:
	@echo "Running tests..."
	@bash -n scripts/backup.sh && echo "✓ backup.sh syntax OK"
	@bash -n scripts/restore.sh && echo "✓ restore.sh syntax OK"
	@bash -n scripts/start.sh && echo "✓ start.sh syntax OK"
	@bash -n install.sh && echo "✓ install.sh syntax OK"
	@echo "All tests passed!"

clean:
	@echo "Cleaning up..."
	@rm -rf /tmp/openclaw-restore-*
	@rm -f *.log
	@echo "Clean complete!"
