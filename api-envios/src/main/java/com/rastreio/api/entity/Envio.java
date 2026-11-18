package com.rastreio.api.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "envios", uniqueConstraints = @UniqueConstraint(name = "uk_envio_codigo", columnNames = "codigo_rastreio"))
public class Envio {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "codigo_rastreio", nullable = false, length = 50)
    private String codigoRastreio;

    @Column(name = "nome_destinatario", nullable = false, length = 150)
    private String nomeDestinatario;

    @Column(name = "ultimo_status", length = 255)
    private String ultimoStatus;

    @Column(nullable = false)
    private boolean entregue;

    @Column(name = "data_atualizacao")
    private LocalDateTime dataAtualizacao;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "envio_historico", joinColumns = @JoinColumn(name = "envio_id"))
    @Column(name = "evento", length = 500)
    @OrderColumn(name = "ordem")
    private List<String> historico = new ArrayList<>();

    @Column(name = "criado_em", nullable = false, updatable = false)
    private LocalDateTime criadoEm;

    @Column(name = "atualizado_em", nullable = false)
    private LocalDateTime atualizadoEm;

    @PrePersist
    void aoCriar() {
        criadoEm = LocalDateTime.now();
        atualizadoEm = criadoEm;
    }

    @PreUpdate
    void aoAtualizar() {
        atualizadoEm = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public String getCodigoRastreio() { return codigoRastreio; }
    public void setCodigoRastreio(String v) { this.codigoRastreio = v; }
    public String getNomeDestinatario() { return nomeDestinatario; }
    public void setNomeDestinatario(String v) { this.nomeDestinatario = v; }
    public String getUltimoStatus() { return ultimoStatus; }
    public void setUltimoStatus(String v) { this.ultimoStatus = v; }
    public boolean isEntregue() { return entregue; }
    public void setEntregue(boolean v) { this.entregue = v; }
    public LocalDateTime getDataAtualizacao() { return dataAtualizacao; }
    public void setDataAtualizacao(LocalDateTime v) { this.dataAtualizacao = v; }
    public List<String> getHistorico() { return historico; }
    public void setHistorico(List<String> v) { this.historico = v; }
    public LocalDateTime getCriadoEm() { return criadoEm; }
    public LocalDateTime getAtualizadoEm() { return atualizadoEm; }
}
