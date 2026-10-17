# ER-диаграмма Access Request

Диаграмма по разделам §3, §4, §5 документации. Текстовое описание — внизу файла.

## Mermaid

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : "имеет"
    ROLES ||--o{ USER_ROLES : "назначена"
    USERS ||--o{ ACCESS_REQUEST : "оформляет"
    ACCESS_TYPE ||--o{ ACCESS_REQUEST : "тип"
    TERM ||--o{ ACCESS_REQUEST : "срок"
    STATUS ||--o{ ACCESS_REQUEST : "текущий"
    ACCESS_REQUEST ||--o{ REQUEST_EVENT : "история"
    USERS ||--o{ REQUEST_EVENT : "действие"
    STATUS ||--o{ REQUEST_EVENT : "из"
    STATUS ||--o{ REQUEST_EVENT : "в"

    USERS {
        INTEGER id PK
        VARCHAR full_name
        VARCHAR email UK
        VARCHAR department
    }

    ROLES {
        INTEGER id PK
        VARCHAR code UK
        VARCHAR name
    }

    USER_ROLES {
        INTEGER user_id PK,FK
        INTEGER role_id PK,FK
    }

    ACCESS_TYPE {
        INTEGER id PK
        VARCHAR code UK
        VARCHAR name
    }

    TERM {
        INTEGER id PK
        VARCHAR name UK
        INTEGER months
    }

    STATUS {
        INTEGER id PK
        VARCHAR code UK
        VARCHAR name
        INTEGER sort_order
        INTEGER is_final
    }

    ACCESS_REQUEST {
        INTEGER id PK
        INTEGER number UK
        VARCHAR resource
        TEXT reason
        TIMESTAMP created_at
        INTEGER access_type_id FK
        INTEGER term_id FK
        INTEGER status_id FK
        INTEGER requester_id FK
    }

    REQUEST_EVENT {
        INTEGER id PK
        VARCHAR event_type
        TEXT comment
        TIMESTAMP created_at
        INTEGER request_id FK
        INTEGER actor_id FK
        INTEGER from_status FK
        INTEGER to_status FK
    }
```

## Схема текстом

**USERS** — сотрудник организации. Связан с ACCESS_REQUEST как заявитель и с REQUEST_EVENT как автор действия.

**ROLES** — справочник: Сотрудник, Согласующий, Администратор доступа (§3). Связьmany-to-many через **USER_ROLES**, так как один пользователь может совмещать роли.

**ACCESS_TYPE** — справочник: Чтение / Запись / Администрирование (§4).

**TERM** — справочник срока: 1 месяц / 3 месяца / 6 месяцев / Бессрочно. Для бессрочного `months = NULL`.

**STATUS** — справочник статусов: Новый / На согласовании / Одобрен / Отклонён / Выполнен. Поля `sort_order` и `is_final` описывают правило §5: переходы только вперёд, после «Выполнен» изменение запрещено.

**ACCESS_REQUEST** — основной объект (§4). Номер уникален, основание проверяется на длину ≥ 15 символов (CHECK-ограничение), дата создания проставляется автоматически.

**REQUEST_EVENT** — история переходов. Хранит, кто и когда согласовал или выдал доступ (§1, §5), включая причину отклонения.

## Связи

| Отношение | Тип | Пояснение |
|---|---|---|
| USERS ↔ ROLES | M:N | через USER_ROLES |
| USERS → ACCESS_REQUEST | 1:N | один сотрудник — много запросов |
| ACCESS_TYPE → ACCESS_REQUEST | 1:N | справочник типа доступа |
| TERM → ACCESS_REQUEST | 1:N | справочник срока |
| STATUS → ACCESS_REQUEST | 1:N | текущий статус запроса |
| ACCESS_REQUEST → REQUEST_EVENT | 1:N | история согласований и выдачи |
| USERS → REQUEST_EVENT | 1:N | автор действия |
| STATUS → REQUEST_EVENT | 1:N (×2) | статус «до» и «после» перехода |

## Переходы статусов (§5)

```
Новый → На согласовании → Одобрен → Выполнен
                        ↘ Отклонён
```

Каждый переход пишется в `REQUEST_EVENT` с `from_status`, `to_status`, `actor_id`.
