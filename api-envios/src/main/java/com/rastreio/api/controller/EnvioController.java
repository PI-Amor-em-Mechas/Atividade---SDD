package com.rastreio.api.controller;

import com.rastreio.api.dto.EnvioRequest;
import com.rastreio.api.dto.EnvioResponse;
import com.rastreio.api.service.EnvioService;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/envios")
public class EnvioController {

    private final EnvioService service;

    public EnvioController(EnvioService service) {
        this.service = service;
    }

    @GetMapping
    public List<EnvioResponse> listar() {
        return service.listar();
    }

    @GetMapping("/{id}")
    public EnvioResponse buscar(@PathVariable Long id) {
        return service.buscarPorId(id);
    }

    @PostMapping
    public ResponseEntity<EnvioResponse> criar(@Valid @RequestBody EnvioRequest req) {
        EnvioResponse criado = service.criar(req);
        return ResponseEntity.created(URI.create("/api/envios/" + criado.id())).body(criado);
    }
}
