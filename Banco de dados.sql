CREATE TABLE usuario (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  email VARCHAR(200) UNIQUE NOT NULL,
  senha_hash VARCHAR(200) NOT NULL,
  role VARCHAR(20) NOT NULL, -- 'almox','supervisor','admin'
  criado_em TIMESTAMP DEFAULT now()
);

CREATE TABLE categoria (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT
);

CREATE TABLE localizacao (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(50) NOT NULL,
  descricao TEXT
);

CREATE TABLE produto (
  id SERIAL PRIMARY KEY,
  sku VARCHAR(80) UNIQUE,
  nome VARCHAR(255) NOT NULL,
  descricao TEXT,
  categoria_id INTEGER REFERENCES categoria(id),
  material_cabeca VARCHAR(100),
  material_cabo VARCHAR(100),
  revestimento VARCHAR(100), -- ex: isolante, imantado
  tamanho VARCHAR(50),
  peso NUMERIC(8,3),
  unidade_medida VARCHAR(20) DEFAULT 'un',
  estoque_atual INTEGER DEFAULT 0,
  estoque_minimo INTEGER DEFAULT 0,
  localizacao_id INTEGER REFERENCES localizacao(id),
  ativo BOOLEAN DEFAULT true,
  criado_em TIMESTAMP DEFAULT now()
);

CREATE TYPE mov_tipo AS ENUM ('entrada','saida','ajuste');

CREATE TABLE movimentacao (
  id SERIAL PRIMARY KEY,
  produto_id INTEGER REFERENCES produto(id) ON DELETE CASCADE,
  tipo mov_tipo NOT NULL,
  quantidade INTEGER NOT NULL,
  saldo_apos INTEGER NOT NULL,
  motivo VARCHAR(200),
  responsavel_id INTEGER REFERENCES usuario(id),
  data_hora TIMESTAMP DEFAULT now(),
  documento_ref VARCHAR(200),
  observacao TEXT
);

-- trigger para atualizar estoque_atual a cada movimentação
CREATE OR REPLACE FUNCTION atualizar_estoque() RETURNS trigger AS $$
DECLARE novo_saldo INTEGER;
BEGIN
  IF NEW.tipo = 'entrada' THEN
    novo_saldo = COALESCE((SELECT estoque_atual FROM produto WHERE id = NEW.produto_id),0) + NEW.quantidade;
  ELSIF NEW.tipo = 'saida' THEN
    novo_saldo = COALESCE((SELECT estoque_atual FROM produto WHERE id = NEW.produto_id),0) - NEW.quantidade;
  ELSE
    -- ajuste: quantidade pode ser positiva ou negativa
    novo_saldo = COALESCE((SELECT estoque_atual FROM produto WHERE id = NEW.produto_id),0) + NEW.quantidade;
  END IF;
  UPDATE produto SET estoque_atual = novo_saldo WHERE id = NEW.produto_id;
  NEW.saldo_apos = novo_saldo;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_movimentacao_after_insert
  BEFORE INSERT ON movimentacao
  FOR EACH ROW EXECUTE FUNCTION atualizar_estoque();

-- Trigger para gerar alerta
CREATE TABLE alerta (
  id SERIAL PRIMARY KEY,
  produto_id INTEGER REFERENCES produto(id),
  tipo VARCHAR(50),
  descricao TEXT,
  criado_em TIMESTAMP DEFAULT now(),
  lido_por INTEGER REFERENCES usuario(id)
);

CREATE OR REPLACE FUNCTION gerar_alerta_baixa_estoque() RETURNS trigger AS $$
DECLARE atual INTEGER;
BEGIN
  SELECT estoque_atual INTO atual FROM produto WHERE id = NEW.produto_id;
  IF atual <= (SELECT estoque_minimo FROM produto WHERE id = NEW.produto_id) THEN
    INSERT INTO alerta (produto_id, tipo, descricao) VALUES (
      NEW.produto_id,
      'estoque_baixo',
      'Estoque abaixo do mínimo configurado. Saldo: ' || atual
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alerta_apos_update
  AFTER UPDATE ON produto
  FOR EACH ROW
  WHEN (OLD.estoque_atual IS DISTINCT FROM NEW.estoque_atual)
  EXECUTE FUNCTION gerar_alerta_baixa_estoque();

-- Dados de exemplo
INSERT INTO usuario (nome, email, senha_hash, role) VALUES
('Almoxarife A','almox@ex.com','$hashfake','almox'),
('Supervisor B','sup@ex.com','$hashfake','supervisor');

INSERT INTO categoria (nome, descricao) VALUES
('Martelos','Martelos diversos'),
('Chaves de Fenda','Diversos tipos de chaves de fenda');

INSERT INTO localizacao (codigo, descricao) VALUES
('A1','Prateleira A1'),
('B2','Gaveta B2');

INSERT INTO produto (sku,nome,categoria_id,material_cabeca,material_cabo,revestimento,tamanho,peso,estoque_atual,estoque_minimo,localizacao_id)
VALUES
('MTH-001','Martelo de aço 500g','1','Aço','Madeira','', '500g',0.500,10,5,1),
('CF-ISO-PL1','Chave de fenda isolada 6mm','2','Aço','Plástico','isolante','6mm',0.120,20,5,2);