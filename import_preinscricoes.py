#!/usr/bin/env python3
"""
Importa pre_inscritons.jsonl para o PostgreSQL (tabelas pre_inscriptions + pre_inscription_courses).

Uso:
    python3 import_preinscricoes.py [--dry-run]

Requer: pip3 install psycopg2-binary
"""

import json
import sys
import os
import argparse
from datetime import datetime

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("Instale: pip3 install psycopg2-binary")
    sys.exit(1)

JSONL_FILE = os.path.join(os.path.dirname(__file__), "pre_inscritons.jsonl")

DB_CONFIG = {
    "host":     os.getenv("POSTGRES_HOST", "localhost"),
    "port":     int(os.getenv("POSTGRES_PORT", "5432")),
    "user":     os.getenv("POSTGRES_USER", "kreativ_user"),
    "password": os.getenv("POSTGRES_PASSWORD", ""),
    "dbname":   os.getenv("POSTGRES_DB", "kreativ_edu"),
}

# Porta exposta do container (para acesso externo ao docker)
# Se rodar DENTRO do container, host=kreativ_postgres, port=5432
# Se rodar na VPS (fora do container), host=localhost e precisa expor porta


def parse_ts(val: str | None) -> datetime | None:
    if not val:
        return None
    try:
        return datetime.fromisoformat(val.replace("Z", "+00:00"))
    except Exception:
        return None


def run_import(dry_run: bool = False):
    print(f"Conectando ao PostgreSQL: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}")

    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    cur = conn.cursor()

    inserted = 0
    updated = 0
    skipped = 0
    errors = 0
    total = 0

    with open(JSONL_FILE, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            total += 1

            try:
                d = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"  ERRO JSON linha {total}: {e}")
                errors += 1
                continue

            person_id = d.get("person_id", "")
            if not person_id:
                print(f"  SKIP linha {total}: person_id vazio")
                skipped += 1
                continue

            # Dados principais
            row = {
                "person_id":               person_id,
                "email":                   d.get("email_usuario"),
                "nome_completo":           d.get("nome_completo_formatado") or d.get("nome_completo"),
                "cpf":                     d.get("cpf"),
                "cpf_formatado":           d.get("cpf_formatado"),
                "cpf_valido":              bool(d.get("cpf_valido", False)),
                "data_nascimento":         d.get("data_nascimento"),
                "idade_calculada":         d.get("idade_calculada") or None,
                "genero":                  d.get("genero"),
                "telefone_whatsapp":       d.get("telefone_whatsapp"),
                "telefone_original":       d.get("telefone_original"),
                "telefone_valido":         bool(d.get("telefone_valido", False)),
                "cep":                     d.get("cep_formatado") or d.get("cep"),
                "endereco":                d.get("endereco"),
                "cidade":                  d.get("cidade_ibge_padronizada") or d.get("cidade_original"),
                "estado":                  d.get("estado_ibge_padronizado") or d.get("estado_original"),
                "disponibilidade":         d.get("disponibilidade_turno"),
                "data_primeira_inscricao": parse_ts(d.get("data_primeira_inscricao")),
                "data_ultima_interacao":   parse_ts(d.get("data_ultima_interacao")),
                "review_required":         bool(
                    d.get("curso_review_required", False)
                    or d.get("disponibilidade_review_required", False)
                    or d.get("cidade_ibge_review_required", False)
                ),
            }

            # Curso(s) interessados
            course_ids = [cid for cid in d.get("cursos_ids", []) if isinstance(cid, int)]

            if not dry_run:
                cur.execute("""
                    INSERT INTO pre_inscriptions (
                        person_id, email, nome_completo,
                        cpf, cpf_formatado, cpf_valido,
                        data_nascimento, idade_calculada, genero,
                        telefone_whatsapp, telefone_original, telefone_valido,
                        cep, endereco, cidade, estado,
                        disponibilidade,
                        data_primeira_inscricao, data_ultima_interacao,
                        review_required
                    ) VALUES (
                        %(person_id)s, %(email)s, %(nome_completo)s,
                        %(cpf)s, %(cpf_formatado)s, %(cpf_valido)s,
                        %(data_nascimento)s, %(idade_calculada)s, %(genero)s,
                        %(telefone_whatsapp)s, %(telefone_original)s, %(telefone_valido)s,
                        %(cep)s, %(endereco)s, %(cidade)s, %(estado)s,
                        %(disponibilidade)s,
                        %(data_primeira_inscricao)s, %(data_ultima_interacao)s,
                        %(review_required)s
                    )
                    ON CONFLICT (person_id) DO UPDATE SET
                        email                   = EXCLUDED.email,
                        nome_completo           = EXCLUDED.nome_completo,
                        cpf                     = EXCLUDED.cpf,
                        cpf_formatado           = EXCLUDED.cpf_formatado,
                        cpf_valido              = EXCLUDED.cpf_valido,
                        data_nascimento         = EXCLUDED.data_nascimento,
                        idade_calculada         = EXCLUDED.idade_calculada,
                        genero                  = EXCLUDED.genero,
                        telefone_whatsapp       = EXCLUDED.telefone_whatsapp,
                        telefone_original       = EXCLUDED.telefone_original,
                        telefone_valido         = EXCLUDED.telefone_valido,
                        cep                     = EXCLUDED.cep,
                        endereco                = EXCLUDED.endereco,
                        cidade                  = EXCLUDED.cidade,
                        estado                  = EXCLUDED.estado,
                        disponibilidade         = EXCLUDED.disponibilidade,
                        data_primeira_inscricao = EXCLUDED.data_primeira_inscricao,
                        data_ultima_interacao   = EXCLUDED.data_ultima_interacao,
                        review_required         = EXCLUDED.review_required
                    RETURNING id, (xmax = 0) AS is_insert
                """, row)

                result = cur.fetchone()
                pre_id, is_insert = result
                if is_insert:
                    inserted += 1
                else:
                    updated += 1

                # Inserir relações curso
                if course_ids:
                    # Limpa relações antigas e reinsere
                    cur.execute("DELETE FROM pre_inscription_courses WHERE pre_inscription_id = %s", (pre_id,))
                    psycopg2.extras.execute_batch(
                        cur,
                        "INSERT INTO pre_inscription_courses (pre_inscription_id, course_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                        [(pre_id, cid) for cid in course_ids]
                    )
            else:
                # Dry-run: apenas conta
                inserted += 1
                print(f"  [DRY] {row['nome_completo']} | {row['telefone_whatsapp']} | cursos={course_ids}")

    if not dry_run:
        conn.commit()
        print(f"\nCommit OK.")

    cur.close()
    conn.close()

    print(f"\n{'='*50}")
    print(f"Total lido   : {total}")
    print(f"Inseridos    : {inserted}")
    print(f"Atualizados  : {updated}")
    print(f"Pulados      : {skipped}")
    print(f"Erros        : {errors}")
    print(f"{'='*50}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Importa pré-inscrições para o PostgreSQL")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria importado, sem gravar")
    args = parser.parse_args()
    run_import(dry_run=args.dry_run)
