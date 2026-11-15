package com.rastreio.api.repository;

import com.rastreio.api.entity.Envio;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EnvioRepository extends JpaRepository<Envio, Long> {
    boolean existsByCodigoRastreio(String codigoRastreio);
}
