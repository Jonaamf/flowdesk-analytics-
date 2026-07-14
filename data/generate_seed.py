"""
FlowDesk Analytics — Seed Data Generator
=========================================
Genera 12 meses de datos sintéticos realistas para el proyecto de portfolio.

Parámetros del caso (Desafío #2):
- 3.200 trials mensuales
- Conversión trial → pago: 4% (meses 1-8) / 7% (meses 9-12)
- Churn mensual: 8.5% (meses 1-8) / 6% (meses 9-12)
- Costo operativo mensual: $310.000
- Gasto en marketing: $85.000/mes

Evento narrativo: en el mes 9 (Sept 2024) el equipo de producto
lanza una mejora en el onboarding que impacta conversión y churn.
"""

import random
import numpy as np
from datetime import date, timedelta

random.seed(42)
np.random.seed(42)

# =============================================================
# CONFIGURACIÓN
# =============================================================

START_DATE = date(2024, 1, 1)
MONTHS = 12
TRIALS_PER_MONTH = 3200
ONBOARDING_CHANGE_MONTH = 9   # sept 2024

# Parámetros antes y después del cambio
CONVERSION_RATE_BEFORE = 0.04
CONVERSION_RATE_AFTER  = 0.07
CHURN_RATE_BEFORE      = 0.085
CHURN_RATE_AFTER       = 0.060

# Distribución de canales de adquisición
CHANNELS = ['organic', 'paid_ads', 'demo', 'referral']
CHANNEL_WEIGHTS = [0.35, 0.40, 0.15, 0.10]

# Distribución de tamaños de empresa
COMPANY_SIZES = ['1-10', '11-50', '51-200', '200+']
SIZE_WEIGHTS = [0.30, 0.40, 0.20, 0.10]

# Distribución de países (empresa y usuario)
COMPANY_COUNTRIES = [
    ('United States', 0.28), ('Brazil', 0.12), ('United Kingdom', 0.10),
    ('Mexico', 0.08), ('Germany', 0.07), ('Argentina', 0.06),
    ('Canada', 0.05), ('Colombia', 0.05), ('Spain', 0.04),
    ('Chile', 0.04), ('France', 0.03), ('Australia', 0.03),
    ('India', 0.03), ('Other', 0.02),
]
USER_COUNTRIES = [c for c, _ in COMPANY_COUNTRIES]
COUNTRY_WEIGHTS = [w for _, w in COMPANY_COUNTRIES]

# Planes y precios
PLANS = ['basic', 'pro', 'enterprise']
PLAN_WEIGHTS = [0.30, 0.55, 0.15]
PLAN_PRICES = {'basic': 49.00, 'pro': 149.00, 'enterprise': 399.00}

# Motivos de cancelación
CANCEL_REASONS = ['too_expensive', 'missing_features', 'competitor', 'no_use', 'other']
CANCEL_WEIGHTS = [0.30, 0.25, 0.20, 0.15, 0.10]

# Gasto de marketing por canal (suma $85.000/mes)
MARKETING_SPEND = {
    'paid_ads': 45000.00,
    'content':  20000.00,
    'events':   12000.00,
    'referral':  8000.00,
}

# =============================================================
# HELPERS
# =============================================================

def month_start(base: date, offset: int) -> date:
    """Primer día del mes base + offset meses."""
    m = base.month + offset
    y = base.year + (m - 1) // 12
    m = (m - 1) % 12 + 1
    return date(y, m, 1)

def random_date_in_month(first_day: date) -> date:
    """Fecha aleatoria dentro del mes dado."""
    if first_day.month == 12:
        last_day = date(first_day.year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = date(first_day.year, first_day.month + 1, 1) - timedelta(days=1)
    delta = (last_day - first_day).days
    return first_day + timedelta(days=random.randint(0, delta))

def weighted_choice(options, weights):
    return random.choices(options, weights=weights, k=1)[0]

# =============================================================
# GENERADORES
# =============================================================

users         = []
trials        = []
subscriptions = []
payments      = []
cancellations = []
marketing     = []

user_id_counter = 1
trial_id_counter = 1
sub_id_counter = 1
pay_id_counter = 1
cancel_id_counter = 1

# Activos entre meses: {sub_id: {sub info}}
active_subs = {}

for month_offset in range(MONTHS):
    current_month = month_start(START_DATE, month_offset)
    month_num = month_offset + 1  # 1-12

    is_after_change = month_num >= ONBOARDING_CHANGE_MONTH
    conv_rate  = CONVERSION_RATE_AFTER if is_after_change else CONVERSION_RATE_BEFORE
    churn_rate = CHURN_RATE_AFTER      if is_after_change else CHURN_RATE_BEFORE

    # ----------------------------------------------------------
    # 1. MARKETING SPEND
    # ----------------------------------------------------------
    for channel, amount in MARKETING_SPEND.items():
        marketing.append({
            'spend_id':    len(marketing) + 1,
            'spend_month': current_month,
            'channel':     channel,
            'amount':      amount,
        })

    # ----------------------------------------------------------
    # 2. NUEVOS USUARIOS Y TRIALS
    # ----------------------------------------------------------
    new_converters_this_month = []

    for _ in range(TRIALS_PER_MONTH):
        uid = user_id_counter
        user_id_counter += 1

        signup = random_date_in_month(current_month)
        channel = weighted_choice(CHANNELS, CHANNEL_WEIGHTS)
        size    = weighted_choice(COMPANY_SIZES, SIZE_WEIGHTS)
        comp_country = weighted_choice(USER_COUNTRIES, COUNTRY_WEIGHTS)
        user_country = weighted_choice(USER_COUNTRIES, COUNTRY_WEIGHTS)

        users.append({
            'user_id':             uid,
            'signup_date':         signup,
            'acquisition_channel': channel,
            'user_country':        user_country,
            'company_country':     comp_country,
            'company_size':        size,
        })

        trial_start = signup
        trial_end   = signup + timedelta(days=14)
        converted   = random.random() < conv_rate

        trials.append({
            'trial_id':     trial_id_counter,
            'user_id':      uid,
            'start_date':   trial_start,
            'end_date':     trial_end,
            'trial_status': 'converted' if converted else 'churned',
        })
        trial_id_counter += 1

        if converted:
            new_converters_this_month.append({
                'user_id':     uid,
                'conv_date':   trial_end + timedelta(days=1),
                'channel':     channel,
                'size':        size,
            })

    # ----------------------------------------------------------
    # 3. NUEVAS SUSCRIPCIONES (conversiones del mes)
    # ----------------------------------------------------------
    for conv in new_converters_this_month:
        plan   = weighted_choice(PLANS, PLAN_WEIGHTS)
        price  = PLAN_PRICES[plan]

        # Pequeña variación de precio para empresas grandes (descuentos negociados)
        if conv['size'] == '200+' and plan == 'enterprise':
            price = round(price * random.uniform(0.85, 1.00), 2)

        sid = sub_id_counter
        sub_id_counter += 1

        sub = {
            'subscription_id': sid,
            'user_id':         conv['user_id'],
            'start_date':      conv['conv_date'],
            'plan_type':       plan,
            'monthly_amount':  price,
            'status':          'active',
        }
        subscriptions.append(sub)
        active_subs[sid] = sub

        # Primer pago al convertir
        payments.append({
            'payment_id':       pay_id_counter,
            'subscription_id':  sid,
            'payment_date':     conv['conv_date'],
            'amount':           price,
            'status':           'success',
        })
        pay_id_counter += 1

    # ----------------------------------------------------------
    # 4. PAGOS MENSUALES DE SUSCRIPCIONES EXISTENTES
    # ----------------------------------------------------------
    for sid, sub in list(active_subs.items()):
        # Solo suscripciones que empezaron en meses anteriores
        if sub['start_date'].month == current_month.month and \
           sub['start_date'].year == current_month.year:
            continue

        pay_date = current_month + timedelta(days=random.randint(0, 4))

        # 3% de fallos de pago, 1% de reembolsos
        roll = random.random()
        if roll < 0.01:
            pay_status = 'refunded'
        elif roll < 0.04:
            pay_status = 'failed'
        else:
            pay_status = 'success'

        payments.append({
            'payment_id':      pay_id_counter,
            'subscription_id': sid,
            'payment_date':    pay_date,
            'amount':          sub['monthly_amount'],
            'status':          pay_status,
        })
        pay_id_counter += 1

    # ----------------------------------------------------------
    # 5. CHURN DE SUSCRIPCIONES ACTIVAS
    # ----------------------------------------------------------
    subs_to_cancel = [
        sid for sid in active_subs
        if random.random() < churn_rate
    ]

    for sid in subs_to_cancel:
        cancel_date = random_date_in_month(current_month)
        reason      = weighted_choice(CANCEL_REASONS, CANCEL_WEIGHTS)

        cancellations.append({
            'cancellation_id':  cancel_id_counter,
            'subscription_id':  sid,
            'cancellation_date': cancel_date,
            'reason':           reason,
        })
        cancel_id_counter += 1

        # Actualizar estado en subscriptions
        for sub in subscriptions:
            if sub['subscription_id'] == sid:
                sub['status'] = 'cancelled'
                break

        del active_subs[sid]

        # 12% de los que cancelan vuelven a suscribirse (win-back)
        # Solo si cancelaron antes del mes 10
        if month_num <= 10 and random.random() < 0.12:
            winback_month = month_offset + random.randint(2, 3)
            if winback_month < MONTHS:
                winback_date = month_start(START_DATE, winback_month) + \
                               timedelta(days=random.randint(5, 20))
                plan  = weighted_choice(PLANS, PLAN_WEIGHTS)
                price = PLAN_PRICES[plan]
                new_sid = sub_id_counter
                sub_id_counter += 1

                new_sub = {
                    'subscription_id': new_sid,
                    'user_id':         active_subs.get(sid, {}).get('user_id',
                                       subscriptions[sid-1]['user_id']),
                    'start_date':      winback_date,
                    'plan_type':       plan,
                    'monthly_amount':  price,
                    'status':          'active',
                }
                subscriptions.append(new_sub)
                active_subs[new_sid] = new_sub

                payments.append({
                    'payment_id':      pay_id_counter,
                    'subscription_id': new_sid,
                    'payment_date':    winback_date,
                    'amount':          price,
                    'status':          'success',
                })
                pay_id_counter += 1

# =============================================================
# EXPORTAR A SQL
# =============================================================

lines = []
lines.append("-- =============================================================")
lines.append("-- FLOWDESK ANALYTICS — SEED DATA")
lines.append("-- =============================================================")
lines.append("-- Datos sintéticos generados para 12 meses (Ene–Dic 2024).")
lines.append("-- Evento clave: mejora de onboarding en mes 9 (Sept 2024).")
lines.append("-- Conversión: 4% → 7%  |  Churn: 8.5% → 6%")
lines.append("-- =============================================================\n")

# users
lines.append(f"-- {len(users):,} usuarios registrados")
lines.append("INSERT INTO users (user_id, signup_date, acquisition_channel, user_country, company_country, company_size) VALUES")
rows = []
for u in users:
    rows.append(
        f"  ({u['user_id']}, '{u['signup_date']}', '{u['acquisition_channel']}', "
        f"'{u['user_country']}', '{u['company_country']}', '{u['company_size']}')"
    )
lines.append(",\n".join(rows) + ";\n")

# trials
lines.append(f"-- {len(trials):,} trials iniciados")
lines.append("INSERT INTO trials (trial_id, user_id, start_date, end_date, trial_status) VALUES")
rows = []
for t in trials:
    rows.append(
        f"  ({t['trial_id']}, {t['user_id']}, '{t['start_date']}', "
        f"'{t['end_date']}', '{t['trial_status']}')"
    )
lines.append(",\n".join(rows) + ";\n")

# subscriptions
lines.append(f"-- {len(subscriptions):,} suscripciones generadas")
lines.append("INSERT INTO subscriptions (subscription_id, user_id, start_date, plan_type, monthly_amount, status) VALUES")
rows = []
for s in subscriptions:
    rows.append(
        f"  ({s['subscription_id']}, {s['user_id']}, '{s['start_date']}', "
        f"'{s['plan_type']}', {s['monthly_amount']}, '{s['status']}')"
    )
lines.append(",\n".join(rows) + ";\n")

# payments
lines.append(f"-- {len(payments):,} transacciones de pago")
lines.append("INSERT INTO payments (payment_id, subscription_id, payment_date, amount, status) VALUES")
rows = []
for p in payments:
    rows.append(
        f"  ({p['payment_id']}, {p['subscription_id']}, '{p['payment_date']}', "
        f"{p['amount']}, '{p['status']}')"
    )
lines.append(",\n".join(rows) + ";\n")

# cancellations
lines.append(f"-- {len(cancellations):,} cancelaciones registradas")
lines.append("INSERT INTO cancellations (cancellation_id, subscription_id, cancellation_date, reason) VALUES")
rows = []
for c in cancellations:
    rows.append(
        f"  ({c['cancellation_id']}, {c['subscription_id']}, "
        f"'{c['cancellation_date']}', '{c['reason']}')"
    )
lines.append(",\n".join(rows) + ";\n")

# marketing_spend
lines.append(f"-- {len(marketing):,} registros de gasto en marketing")
lines.append("INSERT INTO marketing_spend (spend_id, spend_month, channel, amount) VALUES")
rows = []
for m in marketing:
    rows.append(
        f"  ({m['spend_id']}, '{m['spend_month']}', '{m['channel']}', {m['amount']})"
    )
lines.append(",\n".join(rows) + ";\n")

output = "\n".join(lines)
with open('/home/claude/flowdesk-analytics/data/seed_data.sql', 'w') as f:
    f.write(output)

# =============================================================
# RESUMEN
# =============================================================
print("=" * 55)
print("FLOWDESK — SEED DATA GENERADO")
print("=" * 55)
print(f"  Usuarios registrados:       {len(users):>8,}")
print(f"  Trials iniciados:           {len(trials):>8,}")
print(f"  Suscripciones totales:      {len(subscriptions):>8,}")
print(f"  Pagos registrados:          {len(payments):>8,}")
print(f"  Cancelaciones:              {len(cancellations):>8,}")
print(f"  Registros de marketing:     {len(marketing):>8,}")
print("-" * 55)

total_revenue = sum(p['amount'] for p in payments if p['status'] == 'success')
print(f"  Revenue total (12 meses):   ${total_revenue:>12,.2f}")

active_final = len(active_subs)
print(f"  Suscripciones activas (fin):{active_final:>8,}")

converted = sum(1 for t in trials if t['trial_status'] == 'converted')
conv_pct = converted / len(trials) * 100
print(f"  Conversión global:          {conv_pct:>7.1f}%")

churn_total = len(cancellations)
churn_pct = churn_total / len(subscriptions) * 100
print(f"  Cancelaciones / subs:       {churn_pct:>7.1f}%")
print("=" * 55)
print("  Archivo generado: data/seed_data.sql")
print("=" * 55)
