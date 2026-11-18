package com.rastreio.api.service;

import com.rastreio.api.dto.EnvioRequest;
import com.rastreio.api.dto.EnvioResponse;
import com.rastreio.api.entity.Envio;
import com.rastreio.api.exception.CodigoRastreioDuplicadoException;
import com.rastreio.api.exception.EnvioNaoEncontradoException;
import com.rastreio.api.repository.EnvioRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EnvioService {

    private final EnvioRepository repository;

    public EnvioService(EnvioRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<EnvioResponse> listar() {
        return repository.findAll().stream().map(EnvioResponse::de).toList();
    }

    @Transactional(readOnly = true)
    public EnvioResponse buscarPorId(Long id) {
        return repository.findById(id).map(EnvioResponse::de).orElseThrow(() -> new EnvioNaoEncontradoException(id));
    }

    @Transactional
    public EnvioResponse criar(EnvioRequest req) {
        String codigo = req.codigoRastreio().trim();
        if (repository.existsByCodigoRastreio(codigo)) {
            throw new CodigoRastreioDuplicadoException(codigo);
        }
        Envio e = new Envio();
        e.setCodigoRastreio(codigo);
        e.setNomeDestinatario(req.nomeDestinatario().trim());
        String status = req.ultimoStatus() == null || req.ultimoStatus().isBlank()
                ? "AGUARDANDO" : req.ultimoStatus();
        e.setUltimoStatus(status);
        e.setEntregue("ENTREGUE".equals(status));
        e.setDataAtualizacao(LocalDateTime.now());
        List<String> hist = req.historico() != null ? new ArrayList<>(req.historico()) : new ArrayList<>();
        if (hist.isEmpty() && req.ultimoStatus() != null && !req.ultimoStatus().isBlank()) {
            hist.add(req.ultimoStatus());
        }
        e.setHistorico(hist);
        return EnvioResponse.de(repository.saveAndFlush(e));
    }
}
