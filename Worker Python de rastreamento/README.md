# Worker de rastreamento

```bash
pip install -r requirements.txt
export DATABASE_URL=postgresql://user:pass@host:5432/db
export TRACKING_API_URL=http://host/rastreamento
export POLL_INTERVAL_SECONDS=300   # 0 = roda um ciclo e sai
python main.py
```

Variáveis: `API_TIMEOUT_SECONDS` (10), `LOG_LEVEL` (INFO).
