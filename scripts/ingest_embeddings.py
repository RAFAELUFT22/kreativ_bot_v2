import os
import json
import requests
import psycopg2
import uuid
from dotenv import load_dotenv

# Carregar variaveis do .env
load_dotenv('/root/ideias_app/.env', override=True)

DB_CONFIG = {
    'dbname': 'kreativ_edu',
    'user': 'kreativ_user',
    'password': os.getenv('POSTGRES_PASSWORD', 'O3ITwWNXcfqSEpclJBE32viQ'),
    'host': '10.0.2.7',
    'port': '5432'
}

OPEN_ROUTER_API = os.getenv('OPEN_ROUTER_API')
OPEN_ROUTER_URL = "https://openrouter.ai/api/v1/embeddings"
MODEL_NAME = "openai/text-embedding-3-small"

def get_embedding(text):
    headers = {
        "Authorization": f"Bearer {OPEN_ROUTER_API}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": MODEL_NAME,
        "input": text
    }
    try:
        response = requests.post(OPEN_ROUTER_URL, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()['data'][0]['embedding']
    except Exception as e:
        print(f"Erro ao obter embedding: {e}")
        if response.text:
            print(f"Resposta da API: {response.text}")
        return None

def main():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except Exception as e:
        print(f"Erro ao conectar ao banco: {e}")
        # Tentar host docker se localhost falhar
        DB_CONFIG['host'] = 'kreativ_postgres'
        conn = psycopg2.connect(**DB_CONFIG)
        
    cur = conn.cursor()

    # 1. Buscar modulos
    cur.execute("SELECT id, title, content_text FROM modules WHERE content_text IS NOT NULL AND content_text != '';")
    modules = cur.fetchall()
    print(f"Encontrados {len(modules)} modulos para processar.")

    for mod_id, title, content in modules:
        print(f"\n--- Modulo: {title} ({mod_id}) ---")
        
        # Chunking simples (500-1000 caracteres)
        chunks = [content[i:i+800] for i in range(0, len(content), 600)]
        print(f"Gerados {len(chunks)} chunks.")
        
        for i, chunk in enumerate(chunks):
            print(f"Processando chunk {i+1}/{len(chunks)}...", end="\r")
            embedding = get_embedding(chunk)
            if embedding:
                cur.execute("""
                    INSERT INTO document_chunks (id, module_id, chunk_index, content, embedding, created_at)
                    VALUES (%s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (module_id, chunk_index) DO UPDATE SET
                        content = EXCLUDED.content,
                        embedding = EXCLUDED.embedding;
                """, (
                    str(uuid.uuid4()),
                    mod_id, i, chunk, embedding
                ))
        print(f"\nModulo {title} concluido.")
    
    conn.commit()
    cur.close()
    conn.close()
    print("\nProcesso de ingestao finalizado com sucesso.")

if __name__ == "__main__":
    main()
