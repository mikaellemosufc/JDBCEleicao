--CONSULTAS
--votos nulos
SELECT numero_votacao, count(numero_votacao) AS votos_nulos
FROM Votos 
WHERE num_candidato is null 
GROUP BY numero_votacao
ORDER BY numero_votacao;
--okay

--informacoes eleitores
SELECT e.nome, u.localidade, (SELECT extract(year FROM age(e.data_nascimento))) AS idade, e.sexo 
FROM Eleitor e, Urna u
WHERE e.urna = u.urna
ORDER BY e.nome;
--okay

--qtd de votos de cada candidato
SELECT numero_votacao, c.num_candidato, count(v.num_candidato) as total
FROM Votos v RIGHT OUTER JOIN Candidato c
ON c.num_candidato = v.num_candidato
GROUP BY numero_votacao, c.num_candidato
ORDER BY v.numero_votacao, total;
--okay

--informacoes fiscais
SELECT e.nome, e.urna, f.cpf, f.cpf_super, ( en.rua || ' ' || en.numero || ' ' || en.uf) AS endereco ,( t.telefone1, t.telefone2, t.telefone3) AS telefone
FROM Eleitor e, Fiscal f, Endereco en, Telefone t
WHERE e.num_titulo = f.num_titulo AND en.num_titulo = f.num_titulo and f.num_titulo = t.num_titulo
ORDER BY e.nome;
--okay

--informacoes qtds fiscais de cada supervisor
SELECT cpf_super AS supervisor, count(cpf_super) AS fiscais 
FROM Fiscal
GROUP BY cpf_super
HAVING count(cpf_super) > 0;
--okay

--total de votos de cada votacao
SELECT v.numero_votacao, extract(year FROM data_votacao) AS ano, vo.descricao, count(v.numero_votacao) AS total
FROM Votos v, Votacao vo
WHERE v.numero_votacao = vo.numero_votacao
GROUP BY v.numero_votacao, ano, vo.descricao
ORDER BY ano;
--okay

--votos por urna
SELECT e.urna, count(v.numero_votacao) AS votos
FROM eleitor e, votos v
WHERE e.num_titulo = v.num_titulo
GROUP BY e.urna
ORDER BY e.urna
--okay



--VIEW
--informacoes dos candidato
CREATE OR REPLACE VIEW Listagem_Completa AS
(SELECT vo.numero_votacao,(SELECT extract(year FROM data_votacao)) AS Ano, vo.descricao, p.nome_partido, c.num_candidato, e.nome 
FROM Votacao vo, Listagem l, Eleitor e, Candidato c, Partido p 
WHERE l.numero_votacao = vo.numero_votacao AND l.num_candidato = c.num_candidato AND c.num_titulo = e.num_titulo AND p.codigo_partido = c.codigo_partido
ORDER BY Ano, vo.numero_votacao);
--
--EXEMPLO DE FUNCIONAMENTO DA VIEW
SELECT * FROM Listagem_Completa
WHERE nome_partido LIKE 'PT';
--okay


--STORED PROCEDURES
CREATE OR REPLACE FUNCTION Qtd_votos(ano_vot integer, numero_candidato integer) returns void as $$
DECLARE
	x integer;
	y integer;
	total integer;
	resp integer;

BEGIN
	x := (SELECT numero_votacao FROM Listagem_Completa WHERE ano_vot = ano AND num_candidato = numero_candidato);
	y := (SELECT count(num_candidato) FROM Votos WHERE x = numero_votacao AND num_candidato = numero_candidato);
	total := (SELECT count(numero_votacao) FROM Votos WHERE numero_votacao = x);
	resp := (100 * y) / total;
	RAISE NOTICE 'O candidato de numero: %, recebeu % votos, oque corresponde a % porcento do total de votos', numero_candidato, y, resp;
END;
$$ language plpgsql;
--
--EXEMPLO FUNCIONAMENTO DA FUNCAO
SELECT Qtd_votos(2014, 10);
--okay


--TRIGGER 
--Nao pode votar com menos de 16 anos
CREATE OR REPLACE function min_idade() returns TRIGGER AS $$
begin
	if((SELECT extract(year FROM age(NEW.data_nascimento)) AS idade) < 16)
		THEN
			RAISE EXCEPTION 'Não é possivel adicionar o eleitor de titulo numero: %, pois possui menos de 16 anos', NEW.num_titulo;
END if;
	return NEW;
END;
$$ language plpgsql;

CREATE TRIGGER maioridade_16
BEFORE INSERT OR UPDATE ON Eleitor
FOR EACH ROW execute procedure min_idade();
--
--EXEMPLO DE FUNCIONAMENTO DA TRIGGER 
INSERT INTO eleitor (num_titulo, data_nascimento) VALUES (31, '2010-03-24');
--okay

--nao pode votar mais de uma vez na mesma votacao
CREATE OR REPLACE FUNCTION voto_unico() RETURNS TRIGGER AS $$
begin
	if((SELECT count(NEW.num_titulo) FROM Votos WHERE NEW.numero_votacao = numero_votacao AND NEW.num_titulo = num_titulo) > 0)
		THEN
			RAISE EXCEPTION 'O Eleitor de titulo numero: % não pode mais votar nesta votacao', NEW.num_titulo;
END IF;
	return NEW;
END;
$$ language plpgsql;

CREATE TRIGGER voto_unico
before INSERT OR UPDATE ON Votos
FOR EACH ROW execute procedure voto_unico();
--
--EXEMPLO DE FUNCIONAMENTO DA TRIGGER 
INSERT INTO votos VALUES (1, 1, 10);
--okay


--CRIAÇÃO DE USUÁRIO
CREATE USER adm WITH password '1234';
CREATE USER usuario WITH password '1234';

CREATE ROLE moderador;
CREATE ROLE cliente;

GRANT ALL ON database eleicao TO moderador;
GRANT SELECT ON Partido, Eleitor, Candidato, Fiscal, Votos, Local_Votacao, Endereco, Telefone, Listagem, Urna TO cliente;

GRANT moderador TO adm;
GRANT cliente TO usuario;
--okay

