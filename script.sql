-- rodar creates primeiro, após rodar trigger e depois inserts


CREATE database campeonato;

CREATE TABLE Atleta (
    ID_Atleta INT IDENTITY PRIMARY KEY,
    Nome NVARCHAR(100) NOT NULL,
    Data_Nascimento DATE NOT NULL,
    Gênero NVARCHAR(20) NOT NULL,
    Nacionalidade NVARCHAR(50) NOT NULL
);


CREATE TABLE Equipe (
    ID_Equipe INT IDENTITY PRIMARY KEY,
    Nome NVARCHAR(100) NOT NULL,
    Modalidade NVARCHAR(50) NOT NULL,
    País NVARCHAR(50) NOT NULL
);


CREATE TABLE Competição (
    ID_Competição INT IDENTITY PRIMARY KEY,
    Nome NVARCHAR(100) NOT NULL,
    Data_Início DATE NOT NULL,
    Data_Fim DATE NOT NULL,
    Modalidade NVARCHAR(50) NOT NULL,
    Tipo_Formato NVARCHAR(20) NOT NULL 
);


CREATE TABLE Grupo (
    ID_Grupo INT IDENTITY PRIMARY KEY,
    Nome_Grupo NVARCHAR(50) NOT NULL,
    ID_Competição INT NOT NULL,
    FOREIGN KEY (ID_Competição) REFERENCES Competição(ID_Competição)
);


CREATE TABLE Partida (
    ID_Partida INT IDENTITY PRIMARY KEY,
    ID_Competição INT NOT NULL,
    Data_Hora DATETIME NOT NULL,
    Fase NVARCHAR(50) NOT NULL,
    FOREIGN KEY (ID_Competição) REFERENCES Competição(ID_Competição)
);


CREATE TABLE Participação_Equipe (
    ID_Participação INT IDENTITY PRIMARY KEY,
    ID_Equipe INT NOT NULL,
    ID_Competição INT NOT NULL,
    ID_Grupo INT NULL, -- Nulo se for pontos corridos
    FOREIGN KEY (ID_Equipe) REFERENCES Equipe(ID_Equipe),
    FOREIGN KEY (ID_Competição) REFERENCES Competição(ID_Competição),
    FOREIGN KEY (ID_Grupo) REFERENCES Grupo(ID_Grupo)
);


CREATE TABLE Partida_Equipe (
    ID_Partida INT NOT NULL,
    ID_Equipe INT NOT NULL,
    Pontos INT NOT NULL, 
    Gols_Marcados INT NOT NULL,
    Gols_Sofridos INT NOT NULL,
    PRIMARY KEY (ID_Partida, ID_Equipe),
    FOREIGN KEY (ID_Partida) REFERENCES Partida(ID_Partida),
    FOREIGN KEY (ID_Equipe) REFERENCES Equipe(ID_Equipe)
);


CREATE TABLE Atleta_Equipe (
    ID_Atleta INT NOT NULL,
    ID_Equipe INT NOT NULL,
    Data_Início DATE NOT NULL,
    Data_Fim DATE NULL,
    PRIMARY KEY (ID_Atleta, ID_Equipe),
    FOREIGN KEY (ID_Atleta) REFERENCES Atleta(ID_Atleta),
    FOREIGN KEY (ID_Equipe) REFERENCES Equipe(ID_Equipe)
);

CREATE TABLE Campeões (
    ID_Competição INT PRIMARY KEY,
    ID_Equipe INT NOT NULL,
    Pontuação_Total INT NOT NULL,
    Saldo_Gols INT NOT NULL,
    Total_Gols_Marcados INT NOT NULL,
    FOREIGN KEY (ID_Competição) REFERENCES Competição(ID_Competição),
    FOREIGN KEY (ID_Equipe) REFERENCES Equipe(ID_Equipe)
);

CREATE TABLE Pontuação_Competição (
    ID_Equipe INT NOT NULL,
    ID_Competição INT NOT NULL,
    Pontuação_Total INT DEFAULT 0,
    Saldo_Gols INT DEFAULT 0,
    Total_Gols_Marcados INT DEFAULT 0,
    PRIMARY KEY (ID_Equipe, ID_Competição),
    FOREIGN KEY (ID_Equipe) REFERENCES Equipe(ID_Equipe),
    FOREIGN KEY (ID_Competição) REFERENCES Competição(ID_Competição)
);

CREATE TRIGGER AtualizarPontuacao 
ON Partida_Equipe
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Atualizar ou inserir pontuações na tabela Pontuação_Competição
    MERGE Pontuação_Competição AS PC
    USING (
        SELECT 
            pe.ID_Equipe,
            p.ID_Competição,
            SUM(pe.Pontos) AS Pontos_Equipe,
            SUM(pe.Gols_Marcados - pe.Gols_Sofridos) AS Saldo_Gols_Equipe,
            SUM(pe.Gols_Marcados) AS Gols_Marcados_Equipe
        FROM 
            Partida_Equipe pe
        INNER JOIN 
            Partida p ON pe.ID_Partida = p.ID_Partida
        WHERE 
            pe.ID_Equipe IN (SELECT DISTINCT ID_Equipe FROM Inserted)
        GROUP BY 
            pe.ID_Equipe, p.ID_Competição
    ) AS DadosAtualizados (ID_Equipe, ID_Competição, Pontos_Equipe, Saldo_Gols_Equipe, Gols_Marcados_Equipe)
    ON PC.ID_Equipe = DadosAtualizados.ID_Equipe AND PC.ID_Competição = DadosAtualizados.ID_Competição
    WHEN MATCHED THEN
        UPDATE SET 
            Pontuação_Total = DadosAtualizados.Pontos_Equipe,
            Saldo_Gols = DadosAtualizados.Saldo_Gols_Equipe,
            Total_Gols_Marcados = DadosAtualizados.Gols_Marcados_Equipe
    WHEN NOT MATCHED THEN
        INSERT (ID_Equipe, ID_Competição, Pontuação_Total, Saldo_Gols, Total_Gols_Marcados)
        VALUES (DadosAtualizados.ID_Equipe, DadosAtualizados.ID_Competição, DadosAtualizados.Pontos_Equipe, DadosAtualizados.Saldo_Gols_Equipe, DadosAtualizados.Gols_Marcados_Equipe);

    SET NOCOUNT OFF;
END;
GO

CREATE TRIGGER DeterminarCampeao 
ON Pontuação_Competição
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Determinar os campeões de cada competição
    WITH Classificação AS (
        SELECT 
            ID_Equipe,
            ID_Competição,
            Pontuação_Total,
            Saldo_Gols,
            Total_Gols_Marcados,
            ROW_NUMBER() OVER (
                PARTITION BY ID_Competição 
                ORDER BY 
                    Pontuação_Total DESC, 
                    Saldo_Gols DESC, 
                    Total_Gols_Marcados DESC
            ) AS Posição
        FROM 
            Pontuação_Competição
    )
    -- Atualizar ou inserir os campeões
    MERGE Campeões AS C
    USING (
        SELECT 
            ID_Competição,
            ID_Equipe,
            Pontuação_Total,
            Saldo_Gols,
            Total_Gols_Marcados
        FROM 
            Classificação
        WHERE 
            Posição = 1
    ) AS DadosCampeões (ID_Competição, ID_Equipe, Pontuação_Total, Saldo_Gols, Total_Gols_Marcados)
    ON C.ID_Competição = DadosCampeões.ID_Competição
    WHEN MATCHED THEN
        UPDATE SET 
            ID_Equipe = DadosCampeões.ID_Equipe,
            Pontuação_Total = DadosCampeões.Pontuação_Total,
            Saldo_Gols = DadosCampeões.Saldo_Gols,
            Total_Gols_Marcados = DadosCampeões.Total_Gols_Marcados
    WHEN NOT MATCHED THEN
        INSERT (ID_Competição, ID_Equipe, Pontuação_Total, Saldo_Gols, Total_Gols_Marcados)
        VALUES (DadosCampeões.ID_Competição, DadosCampeões.ID_Equipe, DadosCampeões.Pontuação_Total, DadosCampeões.Saldo_Gols, DadosCampeões.Total_Gols_Marcados);

    SET NOCOUNT OFF;
END;
GO



INSERT INTO Atleta (Nome, Data_Nascimento, Gênero, Nacionalidade)
VALUES 
('João Silva', '1995-03-10', 'Masculino', 'Brasil'),
('Maria Oliveira', '1998-07-25', 'Feminino', 'Portugal'),
('Carlos Mendes', '2000-01-15', 'Masculino', 'Espanha'),
('Ana Costa', '1997-12-05', 'Feminino', 'Brasil'),
('Pedro Lima', '1992-06-20', 'Masculino', 'Argentina');

INSERT INTO Equipe (Nome, Modalidade, País)
VALUES 
('Tigres', 'Futebol', 'Brasil'),
('Águias', 'Basquete', 'Espanha'),
('Pumas', 'Voleibol', 'Argentina'),
('Leões', 'Futebol', 'Portugal'),
('Panteras', 'Handebol', 'Brasil');

INSERT INTO Competição (Nome, Data_Início, Data_Fim, Modalidade, Tipo_Formato)
VALUES 
('Campeonato Nacional de Futebol', '2024-01-01', '2024-03-15', 'Futebol', 'Grupos'),
('Liga Internacional de Basquete', '2024-02-01', '2024-04-30', 'Basquete', 'Pontos Corridos'),
('Torneio de Voleibol', '2024-03-01', '2024-05-01', 'Voleibol', 'Grupos'),
('Campeonato de Handebol', '2024-04-01', '2024-06-15', 'Handebol', 'Grupos'),
('Copa Internacional de Futebol', '2024-05-01', '2024-07-01', 'Futebol', 'Pontos Corridos');

INSERT INTO Grupo (Nome_Grupo, ID_Competição)
VALUES 
('Grupo A', 1),
('Grupo B', 1),
('Grupo A', 3),
('Grupo B', 3),
('Grupo A', 4);

INSERT INTO Partida (ID_Competição, Data_Hora, Fase)
VALUES 
(1, '2024-01-05 15:00:00', 'Grupo A'),
(1, '2024-01-10 18:00:00', 'Grupo B'),
(3, '2024-03-05 14:00:00', 'Grupo A'),
(3, '2024-03-10 16:00:00', 'Grupo B'),
(4, '2024-04-15 20:00:00', 'Grupo A');

INSERT INTO Participação_Equipe (ID_Equipe, ID_Competição, ID_Grupo)
VALUES 
(1, 1, 1),
(4, 1, 1),
(2, 3, 3),
(3, 3, 4),
(5, 4, 5);

INSERT INTO Partida_Equipe (ID_Partida, ID_Equipe, Pontos, Gols_Marcados, Gols_Sofridos)
VALUES 
(1, 1, 3, 2, 0),
(1, 4, 0, 0, 2),
(2, 4, 1, 1, 1),
(3, 2, 3, 3, 1),
(5, 5, 3, 2, 1);



INSERT INTO Atleta_Equipe (ID_Atleta, ID_Equipe, Data_Início, Data_Fim)
VALUES 
(1, 1, '2023-01-01', NULL),
(2, 4, '2023-02-01', NULL),
(3, 2, '2023-03-01', NULL),
(4, 3, '2023-04-01', NULL),
(5, 5, '2023-05-01', NULL);



INSERT INTO Partida_Equipe (ID_Partida, ID_Equipe, Pontos, Gols_Marcados, Gols_Sofridos)
VALUES 
(1, 2, 3, 4, 0), 
(5, 3, 0, 1, 2), 
(3, 1, 4, 0, 2), 
(4, 1, 2, 3, 0), 
(4,2, 1, 0, 3);


