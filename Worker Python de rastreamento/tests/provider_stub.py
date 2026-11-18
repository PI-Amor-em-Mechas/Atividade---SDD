"""Stub local executável, também usado pela suíte HTTP."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from time import sleep
from urllib.parse import unquote


class StubHandler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        prefixo = "/rastreamento/"
        if not self.path.startswith(prefixo):
            self.send_error(404)
            return
        codigo = unquote(self.path[len(prefixo):])
        self.server.chamadas.append((self.path, self.headers.get("Authorization")))
        status = self.server.estados.get(codigo, codigo)
        if status == "TIMEOUT":
            sleep(0.25)
        if status == "REDIRECT":
            self.send_response(302)
            self.send_header("Location", "/rastreamento/ENTREGUE")
            self.end_headers()
            return
        if status.isdecimal():
            self.send_response(int(status))
            if status == "429":
                self.send_header("Retry-After", "2")
            self.end_headers()
            return
        payload = {} if status == "SEM_STATUS" else {"status": status}
        if status == "EM_TRANSITO":
            payload["descricao"] = "Objeto em transferência"
        body = b"{" if status == "JSON_INVALIDO" else json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain" if status == "TIPO_INVALIDO" else "application/json")
        self.end_headers()
        if status == "TIMEOUT_CORPO":
            sleep(0.25)
        try:
            self.wfile.write(body)
        except OSError:
            pass


def criar_stub(porta=0):
    servidor = ThreadingHTTPServer(("127.0.0.1", porta), StubHandler)
    servidor.chamadas = []
    servidor.estados = {}
    return servidor


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8081)
    with criar_stub(parser.parse_args().port) as stub:
        stub.serve_forever()
