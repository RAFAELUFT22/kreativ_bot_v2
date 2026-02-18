#!/usr/bin/env python3
"""
Gera SQL para importar pre_inscritons.jsonl.
Saída para stdout, redirecionar para psql.

Uso:
    python3 gerar_sql_import.py | docker exec -i kreativ_postgres psql -U kreativ_user -d kreativ_edu
"""

import json
import sys
import os
from datetime import datetime

JSONL_FILE = os.path.join(os.path.dirname(__file__), "pre_inscritons.jsonl")


def esc(val):
    """Escapa string para SQL."""
    if val is None:
        return "NULL"
    return "'" + str(val).replace("'", "''") + "'"


def esc_bool(val):
    return "TRUE" if val else "FALSE"


def esc_int(val):
    if val is None or val == 0:
        return "NULL"
    try:
        return str(int(val))
    except Exception:
        return "NULL"


def esc_ts(val):
    if not val:
        return "NULL"
    try:
        dt = datetime.fromisoformat(str(val).replace("Z", "+00:00"))
        return f"'{dt.strftime('%Y-%m-%d %H:%M:%S')}'"
    except Exception:
        return "NULL"


print("BEGIN;")
print()

total = 0
with open(JSONL_FILE, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue

        person_id = d.get("person_id", "").strip()
        if not person_id:
            continue
        total += 1

        nome = d.get("nome_completo_formatado") or d.get("nome_completo") or ""
        email = d.get("email_usuario")
        cpf = d.get("cpf")
        cpf_fmt = d.get("cpf_formatado")
        cpf_ok = d.get("cpf_valido", False)
        nasc = d.get("data_nascimento")
        idade = d.get("idade_calculada")
        genero = d.get("genero")
        tel_wpp = d.get("telefone_whatsapp")
        tel_orig = d.get("telefone_original")
        tel_ok = d.get("telefone_valido", False)
        cep = d.get("cep_formatado") or d.get("cep")
        endereco = d.get("endereco")
        cidade = d.get("cidade_ibge_padronizada") or d.get("cidade_original")
        estado = d.get("estado_ibge_padronizado") or d.get("estado_original")
        disp = d.get("disponibilidade_turno")
        dt_pri = d.get("data_primeira_inscricao")
        dt_ult = d.get("data_ultima_interacao")
        review = (
            d.get("curso_review_required", False)
            or d.get("disponibilidade_review_required", False)
            or d.get("cidade_ibge_review_required", False)
        )

        print(f"""INSERT INTO pre_inscriptions (
    person_id, email, nome_completo,
    cpf, cpf_formatado, cpf_valido,
    data_nascimento, idade_calculada, genero,
    telefone_whatsapp, telefone_original, telefone_valido,
    cep, endereco, cidade, estado,
    disponibilidade, data_primeira_inscricao, data_ultima_interacao,
    review_required
) VALUES (
    {esc(person_id)}, {esc(email)}, {esc(nome)},
    {esc(cpf)}, {esc(cpf_fmt)}, {esc_bool(cpf_ok)},
    {esc(nasc)}, {esc_int(idade)}, {esc(genero)},
    {esc(tel_wpp)}, {esc(tel_orig)}, {esc_bool(tel_ok)},
    {esc(cep)}, {esc(endereco)}, {esc(cidade)}, {esc(estado)},
    {esc(disp)}, {esc_ts(dt_pri)}, {esc_ts(dt_ult)},
    {esc_bool(review)}
) ON CONFLICT (person_id) DO UPDATE SET
    email = EXCLUDED.email,
    nome_completo = EXCLUDED.nome_completo,
    telefone_whatsapp = EXCLUDED.telefone_whatsapp,
    cidade = EXCLUDED.cidade,
    estado = EXCLUDED.estado;""")

        # Relações com cursos
        course_ids = [cid for cid in d.get("cursos_ids", []) if isinstance(cid, int)]
        if course_ids:
            print(f"""INSERT INTO pre_inscription_courses (pre_inscription_id, course_id)
SELECT p.id, c.id FROM pre_inscriptions p, courses c
WHERE p.person_id = {esc(person_id)} AND c.id IN ({','.join(str(c) for c in course_ids)})
ON CONFLICT DO NOTHING;""")

        print()

print("COMMIT;")
print(f"-- Total: {total} registros", file=sys.stderr)
