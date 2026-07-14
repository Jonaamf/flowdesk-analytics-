-- =============================================================
-- FLOWDESK ANALYTICS — DATABASE SCHEMA
-- =============================================================
-- Proyecto de portfolio: análisis de unit economics para una
-- startup SaaS ficticia (caso FlowDesk).
--
-- Herramientas: SQL · Google Sheets · Looker Studio
-- Autor: [tu nombre]
-- =============================================================


-- -------------------------------------------------------------
-- TABLA 1: users
-- Registro de cada persona que se registra en FlowDesk.
-- Un usuario puede venir de una demo, un anuncio, búsqueda
-- orgánica o recomendación de otro cliente.
-- -------------------------------------------------------------
CREATE TABLE users (
    user_id             SERIAL          PRIMARY KEY,
    signup_date         DATE            NOT NULL,

    -- Canal por el que llegó el usuario a FlowDesk.
    -- Clave para calcular CAC por canal y entender qué
    -- fuente de adquisición trae clientes más rentables.
    acquisition_channel VARCHAR(20)     NOT NULL
                        CHECK (acquisition_channel IN (
                            'organic',    -- búsqueda sin publicidad pagada
                            'paid_ads',   -- anuncios en Google / LinkedIn
                            'demo',       -- vendedor hizo demo en vivo
                            'referral'    -- recomendado por otro cliente
                        )),

    -- País de la persona que se registró.
    -- Útil para análisis de marketing y cobertura geográfica.
    user_country        VARCHAR(60)     NOT NULL,

    -- País donde opera la empresa cliente.
    -- En B2B, este es el dato relevante para análisis de mercado:
    -- el ingreso viene de la empresa, no de la persona.
    company_country     VARCHAR(60)     NOT NULL,

    -- Tamaño de la empresa cliente.
    -- Permite identificar el ICP (Ideal Customer Profile):
    -- qué segmento convierte mejor y genera menor churn.
    company_size        VARCHAR(20)     NOT NULL
                        CHECK (company_size IN (
                            '1-10',       -- microempresa
                            '11-50',      -- pequeña empresa
                            '51-200',     -- empresa mediana
                            '200+'        -- empresa grande
                        ))
);


-- -------------------------------------------------------------
-- TABLA 2: trials
-- Cada período de prueba gratuita iniciado por un usuario.
-- Un usuario tiene exactamente un trial (no se permiten
-- múltiples trials para el mismo user_id).
-- El trial_status refleja el resultado final del período.
-- -------------------------------------------------------------
CREATE TABLE trials (
    trial_id            SERIAL          PRIMARY KEY,
    user_id             INT             NOT NULL REFERENCES users(user_id),

    start_date          DATE            NOT NULL,

    -- Fecha en que vence el acceso gratuito (start_date + 14 días).
    end_date            DATE            NOT NULL,

    -- Resultado final del trial.
    -- 'active'    → el período de prueba aún no terminó
    -- 'converted' → el usuario pasó a una suscripción paga
    -- 'churned'   → el trial terminó sin conversión
    trial_status        VARCHAR(15)     NOT NULL
                        CHECK (trial_status IN (
                            'active',
                            'converted',
                            'churned'
                        )),

    CONSTRAINT uq_user_trial UNIQUE (user_id)
);


-- -------------------------------------------------------------
-- TABLA 3: subscriptions
-- Suscripciones pagas. Un usuario puede tener más de una
-- si cancela y vuelve a suscribirse en el futuro.
-- Cada suscripción tiene un plan con precio fijo mensual.
-- -------------------------------------------------------------
CREATE TABLE subscriptions (
    subscription_id     SERIAL          PRIMARY KEY,
    user_id             INT             NOT NULL REFERENCES users(user_id),

    start_date          DATE            NOT NULL,

    -- Plan contratado. Tres niveles de precio para
    -- permitir análisis de LTV y churn por segmento.
    plan_type           VARCHAR(20)     NOT NULL
                        CHECK (plan_type IN (
                            'basic',        -- $49/mes  — equipos pequeños
                            'pro',          -- $149/mes — el plan principal
                            'enterprise'    -- $399/mes — empresas grandes
                        )),

    -- Monto mensual efectivo. Puede diferir del precio de lista
    -- si se aplicaron descuentos promocionales.
    monthly_amount      NUMERIC(10,2)   NOT NULL,

    -- Estado actual de la suscripción.
    status              VARCHAR(15)     NOT NULL
                        CHECK (status IN (
                            'active',
                            'cancelled'
                        ))
);


-- -------------------------------------------------------------
-- TABLA 4: payments
-- Cada intento de cobro mensual por suscripción.
-- Desacoplado de subscriptions para modelar fallos de pago,
-- reembolsos y pagos parciales con fidelidad real.
-- Un pago fallido no cancela la suscripción automáticamente
-- (suele haber un período de gracia de 3-7 días).
-- -------------------------------------------------------------
CREATE TABLE payments (
    payment_id          SERIAL          PRIMARY KEY,
    subscription_id     INT             NOT NULL REFERENCES subscriptions(subscription_id),

    payment_date        DATE            NOT NULL,
    amount              NUMERIC(10,2)   NOT NULL,

    -- Estado del intento de cobro.
    -- 'success'  → cobro exitoso
    -- 'failed'   → tarjeta rechazada / fondos insuficientes
    -- 'refunded' → el cliente solicitó devolución
    status              VARCHAR(15)     NOT NULL
                        CHECK (status IN (
                            'success',
                            'failed',
                            'refunded'
                        ))
);


-- -------------------------------------------------------------
-- TABLA 5: cancellations
-- Registro de cada cancelación de suscripción con motivo.
-- Esta tabla es la más valiosa para el equipo de producto:
-- el motivo de cancelación define qué hay que arreglar primero.
-- Relación 1:1 con subscriptions (una cancelación por suscripción).
-- -------------------------------------------------------------
CREATE TABLE cancellations (
    cancellation_id     SERIAL          PRIMARY KEY,
    subscription_id     INT             NOT NULL REFERENCES subscriptions(subscription_id),

    cancellation_date   DATE            NOT NULL,

    -- Motivo de cancelación declarado por el usuario.
    -- Permite segmentar el churn por causa y priorizar
    -- iniciativas de retención o producto.
    reason              VARCHAR(30)     NOT NULL
                        CHECK (reason IN (
                            'too_expensive',      -- precio fuera de presupuesto
                            'missing_features',   -- falta funcionalidad clave
                            'competitor',         -- se fue a la competencia
                            'no_use',             -- dejó de usar el producto
                            'other'               -- otro motivo no categorizado
                        )),

    CONSTRAINT uq_subscription_cancellation UNIQUE (subscription_id)
);


-- -------------------------------------------------------------
-- TABLA 6: marketing_spend
-- Gasto mensual de marketing por canal de adquisición.
-- Se cruza con conversiones para calcular el CAC real
-- por canal: cuánto costó cada cliente según de dónde vino.
-- -------------------------------------------------------------
CREATE TABLE marketing_spend (
    spend_id            SERIAL          PRIMARY KEY,

    -- Primer día del mes al que corresponde el gasto.
    -- Usar el primer día del mes como convención estándar
    -- facilita los GROUP BY y los JOINs por período.
    spend_month         DATE            NOT NULL,

    -- Canal al que se destinó la inversión.
    channel             VARCHAR(20)     NOT NULL
                        CHECK (channel IN (
                            'paid_ads',   -- Google Ads, LinkedIn Ads
                            'content',    -- blog, SEO, videos
                            'events',     -- conferencias, webinars
                            'referral'    -- programa de referidos
                        )),

    amount              NUMERIC(10,2)   NOT NULL,

    CONSTRAINT uq_month_channel UNIQUE (spend_month, channel)
);


-- =============================================================
-- ÍNDICES
-- Aceleran las queries más frecuentes del análisis:
-- filtros por fecha, joins entre tablas y agrupaciones.
-- =============================================================

-- users: búsquedas por canal y segmentación geográfica
CREATE INDEX idx_users_channel        ON users(acquisition_channel);
CREATE INDEX idx_users_signup_date    ON users(signup_date);
CREATE INDEX idx_users_company_country ON users(company_country);
CREATE INDEX idx_users_company_size   ON users(company_size);

-- trials: análisis de funnel por período
CREATE INDEX idx_trials_user          ON trials(user_id);
CREATE INDEX idx_trials_start_date    ON trials(start_date);
CREATE INDEX idx_trials_status        ON trials(trial_status);

-- subscriptions: análisis de MRR y cohortes
CREATE INDEX idx_subs_user            ON subscriptions(user_id);
CREATE INDEX idx_subs_start_date      ON subscriptions(start_date);
CREATE INDEX idx_subs_plan            ON subscriptions(plan_type);
CREATE INDEX idx_subs_status          ON subscriptions(status);

-- payments: análisis de ingresos reales vs facturados
CREATE INDEX idx_payments_sub         ON payments(subscription_id);
CREATE INDEX idx_payments_date        ON payments(payment_date);
CREATE INDEX idx_payments_status      ON payments(status);

-- cancellations: análisis de churn por motivo
CREATE INDEX idx_cancel_sub           ON cancellations(subscription_id);
CREATE INDEX idx_cancel_date          ON cancellations(cancellation_date);
CREATE INDEX idx_cancel_reason        ON cancellations(reason);

-- marketing_spend: análisis de CAC por canal y período
CREATE INDEX idx_spend_month          ON marketing_spend(spend_month);
CREATE INDEX idx_spend_channel        ON marketing_spend(channel);
