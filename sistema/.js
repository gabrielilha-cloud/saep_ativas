const express = require('express');
const mysql = require('mysql');
const bodyParser = require('body-parser');

const app = express();

app.use(bodyParser.json());

// Conexão com o banco de dados
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'nome_do_banco'
});

db.connect(err => {
    if (err) {
        console.error('Erro ao conectar ao banco de dados:', err);
        return;
    }
    console.log('Conectado ao banco de dados.');
});

// Rota para adicionar uma ferramenta
app.post('/tools', (req, res) => {
    const { name, description } = req.body;
    const query = 'INSERT INTO tools (name, description) VALUES (?, ?)';
    db.query(query, [name, description], (err, result) => {
        if (err) {
            console.error('Erro ao inserir ferramenta:', err);
            res.status(500).send('Erro ao inserir ferramenta.');
            return;
        }
        res.status(200).send('Ferramenta cadastrada com sucesso!');
    });
});

// Rota para listar ferramentas
app.get('/tools', (req, res) => {
    const query = 'SELECT * FROM tools';
    db.query(query, (err, results) => {
        if (err) {
            console.error('Erro ao buscar ferramentas:', err);
            res.status(500).send('Erro ao buscar ferramentas.');
            return;
        }
        res.status(200).json(results);
    });
});

// Inicia o servidor
app.listen(3000, () => {
    console.log('Servidor rodando na porta 3000.');
});