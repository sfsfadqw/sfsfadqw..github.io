-- ============================================================
--  Access Request — логическая схема данных (ER)
--  Источник: документация.docx §3, §4, §5, §11
--  Диаграмма: er-diagram.md (Mermaid), er-diagram.drawio
--  SQL универсальный: работает в MySQL 8 и PostgreSQL
-- ============================================================

-- ---------- Пользователи и роли (§3) ----------

CREATE TABLE users (
  id          INTEGER      PRIMARY KEY,
  full_name   VARCHAR(150) NOT NULL,
  email       VARCHAR(150) NOT NULL,
  department  VARCHAR(150),
  CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE roles (
  id    INTEGER     PRIMARY KEY,
  code  VARCHAR(30) NOT NULL,           -- employee / approver / admin
  name  VARCHAR(100) NOT NULL,          -- Сотрудник / Согласующий / Администратор доступа
  CONSTRAINT uq_roles_code UNIQUE (code)
);

CREATE TABLE user_roles (
  user_id  INTEGER NOT NULL,
  role_id  INTEGER NOT NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id)  ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles (id)  ON DELETE CASCADE
);

-- ---------- Справочники (§4) ----------

CREATE TABLE access_type (
  id    INTEGER     PRIMARY KEY,
  code  VARCHAR(30) NOT NULL,           -- read / write / admin
  name  VARCHAR(100) NOT NULL,          -- Чтение / Запись / Администрирование
  CONSTRAINT uq_access_type_code UNIQUE (code)
);

CREATE TABLE term (
  id      INTEGER     PRIMARY KEY,
  name    VARCHAR(50) NOT NULL,         -- 1 месяц / 3 месяца / 6 месяцев / Бессрочно
  months  INTEGER,                      -- NULL = бессрочно
  CONSTRAINT uq_term_name UNIQUE (name)
);

CREATE TABLE status (
  id         INTEGER     PRIMARY KEY,
  code       VARCHAR(30) NOT NULL,      -- new / review / approved / rejected / done
  name       VARCHAR(50) NOT NULL,      -- Новый / На согласовании / Одобрен / Отклонён / Выполнен
  sort_order INTEGER     NOT NULL,      -- порядок переходов (§5: только вперёд)
  is_final   INTEGER     NOT NULL DEFAULT 0,  -- 1 = изменение запрещено
  CONSTRAINT uq_status_code UNIQUE (code)
);

-- ---------- Основной объект: запрос доступа (§4) ----------

CREATE TABLE access_request (
  id             INTEGER      PRIMARY KEY,
  number         INTEGER      NOT NULL,          -- уникальный номер, например 1043
  resource       VARCHAR(200) NOT NULL,          -- название информационного ресурса
  access_type_id INTEGER      NOT NULL,
  reason         TEXT         NOT NULL,          -- основание, не менее 15 символов
  term_id        INTEGER,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_id      INTEGER      NOT NULL,
  requester_id   INTEGER      NOT NULL,
  CONSTRAINT uq_access_request_number UNIQUE (number),
  CONSTRAINT ck_access_request_reason CHECK (CHAR_LENGTH(TRIM(reason)) >= 15),
  CONSTRAINT fk_ar_access_type FOREIGN KEY (access_type_id) REFERENCES access_type (id),
  CONSTRAINT fk_ar_term        FOREIGN KEY (term_id)        REFERENCES term (id),
  CONSTRAINT fk_ar_status      FOREIGN KEY (status_id)      REFERENCES status (id),
  CONSTRAINT fk_ar_requester   FOREIGN KEY (requester_id)   REFERENCES users (id)
);

CREATE INDEX ix_access_request_requester ON access_request (requester_id);
CREATE INDEX ix_access_request_status    ON access_request (status_id);

-- ---------- История действий: кто согласовал и когда выдан доступ (§1, §5) ----------

CREATE TABLE request_event (
  id          INTEGER    PRIMARY KEY,
  request_id  INTEGER    NOT NULL,
  event_type  VARCHAR(30) NOT NULL,      -- submit / approve / reject / grant
  actor_id    INTEGER    NOT NULL,
  from_status INTEGER,
  to_status   INTEGER,
  comment     TEXT,                      -- причина отклонения
  created_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_re_request   FOREIGN KEY (request_id)  REFERENCES access_request (id) ON DELETE CASCADE,
  CONSTRAINT fk_re_actor     FOREIGN KEY (actor_id)    REFERENCES users (id),
  CONSTRAINT fk_re_from      FOREIGN KEY (from_status) REFERENCES status (id),
  CONSTRAINT fk_re_to        FOREIGN KEY (to_status)   REFERENCES status (id)
);

CREATE INDEX ix_request_event_request ON request_event (request_id);

-- ---------- Начальные данные ----------

INSERT INTO roles (id, code, name) VALUES
  (1, 'employee', 'Сотрудник'),
  (2, 'approver', 'Согласующий'),
  (3, 'admin',    'Администратор доступа');

INSERT INTO access_type (id, code, name) VALUES
  (1, 'read',  'Чтение'),
  (2, 'write', 'Запись'),
  (3, 'admin', 'Администрирование');

INSERT INTO term (id, name, months) VALUES
  (1, '1 месяц',    1),
  (2, '3 месяца',   3),
  (3, '6 месяцев',  6),
  (4, 'Бессрочно',  NULL);

INSERT INTO status (id, code, name, sort_order, is_final) VALUES
  (1, 'new',      'Новый',            1, 0),
  (2, 'review',   'На согласовании',  2, 0),
  (3, 'approved', 'Одобрен',          3, 0),
  (4, 'rejected', 'Отклонён',         4, 1),
  (5, 'done',     'Выполнен',         5, 1);

-- Демонстрационные запросы (§10, экран 1)
INSERT INTO access_request (id, number, resource, access_type_id, reason, term_id, created_at, status_id, requester_id) VALUES
  (1, 1043, 'База данных клиентов', 1, 'Нужен доступ для ежемесячной отчётности.',              2, '2025-05-12 09:15:00', 1, 1),
  (2, 1042, 'CRM (отдел продаж)',   2, 'Ведение сделок и обновление карточек клиентов.',       3, '2025-05-04 11:40:00', 2, 1),
  (3, 1041, 'Хранилище отчётов',     1, 'Подготовка квартального отчёта для руководства.',     4, '2025-04-28 14:05:00', 5, 1);
