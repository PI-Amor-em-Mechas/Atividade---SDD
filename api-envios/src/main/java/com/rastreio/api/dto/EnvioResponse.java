package com.rastreio.api.dto;

import com.rastreio.api.entity.Envio;
import java.time.LocalDateTime;
import java.util.List;

public record EnvioResponse(
        Long id,
        String codigoRastreio,
        String nomeDestinatario,
        String ultimoStatus,
        boolean entregue,
        LocalDateTime dataAtualizacao,
        List<String> historico,
        LocalDateTime criadoEm,
        LocalDateTime atualizadoEm) {

    public static EnvioResponse de(Envio e) {
        return new EnvioResponse(e.getId(), e.getCodigoRastreio(), e.getNomeDestinatario(), e.getUltimoStatus(),
                e.isEntregue(), e.getDataAtualizacao(), List.copyOf(e.getHistorico()), e.getCriadoEm(), e.getAtualizadoEm());
    }
}
