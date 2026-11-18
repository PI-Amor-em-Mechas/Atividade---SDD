package com.rastreio.api.exception;

public class CodigoRastreioDuplicadoException extends RuntimeException {
    public CodigoRastreioDuplicadoException(String codigo) {
        super("Já existe encomenda com o código de rastreio: " + codigo);
    }
}
