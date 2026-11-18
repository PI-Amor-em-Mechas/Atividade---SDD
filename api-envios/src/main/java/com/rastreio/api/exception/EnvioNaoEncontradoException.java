package com.rastreio.api.exception;

public class EnvioNaoEncontradoException extends RuntimeException {
    public EnvioNaoEncontradoException(Long id) {
        super("Encomenda não encontrada: id=" + id);
    }
}
