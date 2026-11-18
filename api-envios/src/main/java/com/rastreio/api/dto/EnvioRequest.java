package com.rastreio.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record EnvioRequest(
        @NotBlank(message = "codigoRastreio é obrigatório") @Size(max = 50, message = "codigoRastreio deve ter no máximo 50 caracteres") String codigoRastreio,
        @NotBlank(message = "nomeDestinatario é obrigatório") @Size(max = 150, message = "nomeDestinatario deve ter no máximo 150 caracteres") String nomeDestinatario,
        String ultimoStatus,
        Boolean entregue,
        List<String> historico) {
}
