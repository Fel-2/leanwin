.PHONY: up down restart logs ssh shell vnc rdp clean reprovision health build-test status

SSH_PORT ?= 2223
BS_PORT  ?= 2224
USER     ?= builder
KEY      ?= ./leanwin_key

up:
	docker compose up -d
	@echo "VM starting. Watch at http://localhost:8006 (~15-20 min on first boot)."

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f windows

ssh:
	ssh -p $(SSH_PORT) -i $(KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USER)@localhost

shell: ssh

vnc:
	@echo "Open http://localhost:8006"
	@command -v xdg-open >/dev/null && xdg-open http://localhost:8006 || true

rdp:
	@echo "Connect RDP client to localhost:3389 (user=$(USER))"

health:
	@curl -fsS http://localhost:$(BS_PORT)/health && echo " — build server ready" || echo "build server not responding"

build-test:
	curl -s -X POST http://localhost:$(BS_PORT)/exec \
	  -H 'Content-Type: application/json' \
	  -d '{"cmd": "cl /? 2>&1 | findstr Microsoft"}'

reprovision:
	docker compose exec windows /oem/install.bat

status:
	@docker compose ps
	@echo
	@$(MAKE) --no-print-directory health

clean:
	docker compose down
	@echo "Removing storage/ (VM disk) — Ctrl-C now to abort"
	@sleep 3
	rm -rf storage
	@echo "Run 'make up' for a fresh VM."
