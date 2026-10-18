# Online Bookstore – Entity-Relationship Diagram

Legend: **PK** = primary key, **FK** = foreign key, **UQ** = unique, `NN` = NOT NULL.
Crow's Foot (text): `||` = exactly one, `o{` = zero or many, `|{` = one or many.

---

## 1. Relationship Overview (ASCII)

```
                     ┌──────────────┐
                     │  publishers  │
                     └──────┬───────┘
                            │ 1
                            │ publishes
                            │ N
 ┌──────────┐ 1   N ┌───────┴──────┐ 1   N ┌────────────────┐ N   1 ┌────────────┐
 │ authors  ├───────┤ book_authors ├───────┤                │       │            │
 └──────────┘       └──────────────┘       │     books      │       │            │
        (M:N resolved by junction)         │                │       │            │
                                           │                │ 1   N ┌────────────┐
 ┌────────────┐ 1  N ┌─────────────────┐ N │                ├───────┤ order_items│ N   1 ┌──────────┐
 │ categories ├──────┤ book_categories ├───┤                │       └────────────┘───────┤  orders  │
 └─────┬──────┘      └─────────────────┘ 1 └───────┬────────┘                              └────┬─────┘
       │ 0..1 parent                               │ 1                                          │ N
       └──► (self reference: sub-genres)           │ writes/has                                 │ places
                                                   │ N                                          │ 1
                                             ┌─────┴─────┐  N               1             ┌─────┴─────┐
                                             │  reviews  ├──────────────────────────────── │ customers │
                                             └───────────┘          writes                 └───────────┘
```

---

## 2. Entities and Attributes

### authors
| Column | Type | Key / Constraint |
|---|---|---|
| author_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| first_name | VARCHAR(100) | NN |
| last_name | VARCHAR(100) | NN |
| biography | TEXT | NULL |
| nationality | VARCHAR(60) | NULL |
| birth_date | DATE | NULL |
| created_at | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |

### publishers
| Column | Type | Key / Constraint |
|---|---|---|
| publisher_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| name | VARCHAR(150) | NN, **UQ** |
| address | VARCHAR(255) | NULL |
| city | VARCHAR(100) | NULL |
| country | VARCHAR(100) | NULL |
| website | VARCHAR(255) | NULL |
| created_at | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |

### categories
| Column | Type | Key / Constraint |
|---|---|---|
| category_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| name | VARCHAR(100) | NN, **UQ** |
| description | VARCHAR(255) | NULL |
| parent_category_id | INT UNSIGNED | **FK** → categories.category_id (ON DELETE SET NULL) |

### books
| Column | Type | Key / Constraint |
|---|---|---|
| book_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| isbn | CHAR(13) | NN, **UQ** |
| title | VARCHAR(255) | NN |
| publisher_id | INT UNSIGNED | **FK** → publishers.publisher_id (ON DELETE RESTRICT), NN |
| price | DECIMAL(10,2) | NN, CHECK (price > 0) |
| stock_quantity | INT | NN, DEFAULT 0, CHECK (≥ 0) |
| publication_date | DATE | NULL |
| pages | SMALLINT UNSIGNED | NULL, CHECK (> 0) |
| language | VARCHAR(30) | NN, DEFAULT 'English' |
| description | TEXT | NULL |
| created_at | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |

### book_authors (junction)
| Column | Type | Key / Constraint |
|---|---|---|
| book_id | INT UNSIGNED | **PK (composite), FK** → books (CASCADE) |
| author_id | INT UNSIGNED | **PK (composite), FK** → authors (CASCADE) |
| author_order | TINYINT UNSIGNED | NN, DEFAULT 1, CHECK (≥ 1) |

### book_categories (junction)
| Column | Type | Key / Constraint |
|---|---|---|
| book_id | INT UNSIGNED | **PK (composite), FK** → books (CASCADE) |
| category_id | INT UNSIGNED | **PK (composite), FK** → categories (CASCADE) |

### customers
| Column | Type | Key / Constraint |
|---|---|---|
| customer_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| first_name | VARCHAR(100) | NN |
| last_name | VARCHAR(100) | NN |
| email | VARCHAR(255) | NN, **UQ** |
| password_hash | VARCHAR(255) | NN |
| phone | VARCHAR(20) | NULL |
| address / city / postal_code | VARCHAR | NULL |
| country | VARCHAR(100) | NN, DEFAULT 'Vietnam' |
| created_at | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |

### orders
| Column | Type | Key / Constraint |
|---|---|---|
| order_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| customer_id | INT UNSIGNED | **FK** → customers (ON DELETE RESTRICT), NN |
| order_date | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |
| status | ENUM('pending','processing','shipped','delivered','cancelled') | NN, DEFAULT 'pending' |
| total_amount | DECIMAL(10,2) | NN, DEFAULT 0, CHECK (≥ 0) |
| shipping_address | VARCHAR(255) | NN |
| shipping_city | VARCHAR(100) | NN |
| shipping_postal_code | VARCHAR(20) | NULL |
| shipping_country | VARCHAR(100) | NN, DEFAULT 'Vietnam' |

### order_items
| Column | Type | Key / Constraint |
|---|---|---|
| order_item_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| order_id | INT UNSIGNED | **FK** → orders (ON DELETE CASCADE), NN, **UQ (order_id, book_id)** |
| book_id | INT UNSIGNED | **FK** → books (ON DELETE RESTRICT), NN |
| quantity | INT UNSIGNED | NN, DEFAULT 1, CHECK (> 0) |
| unit_price | DECIMAL(10,2) | NN, CHECK (> 0) – price at purchase time |
| subtotal | DECIMAL(12,2) | GENERATED = quantity × unit_price |

### reviews
| Column | Type | Key / Constraint |
|---|---|---|
| review_id | INT UNSIGNED AUTO_INCREMENT | **PK** |
| book_id | INT UNSIGNED | **FK** → books (ON DELETE CASCADE), NN |
| customer_id | INT UNSIGNED | **FK** → customers (ON DELETE CASCADE), NN, **UQ (customer_id, book_id)** |
| rating | TINYINT UNSIGNED | NN, CHECK (rating BETWEEN 1 AND 5) |
| comment | TEXT | NULL |
| review_date | DATETIME | NN, DEFAULT CURRENT_TIMESTAMP |

---

## 3. Relationships and Cardinality

| # | Relationship | Cardinality | Implemented by | Crow's Foot |
|---|---|---|---|---|
| 1 | books ↔ authors | **M:N** | junction `book_authors` | `books ||--|{ book_authors }|--|| authors` |
| 2 | books ↔ categories | **M:N** | junction `book_categories` | `books ||--|{ book_categories }|--|| categories` |
| 3 | publishers → books | **1:N** | `books.publisher_id` | `publishers ||--o{ books` |
| 4 | categories → categories (parent) | **1:N** (self) | `categories.parent_category_id` | `categories ||--o{ categories` |
| 5 | customers → orders | **1:N** | `orders.customer_id` | `customers ||--o{ orders` |
| 6 | orders ↔ books | **M:N** | junction `order_items` | `orders ||--|{ order_items }o--|| books` |
| 7 | customers → reviews | **1:N** | `reviews.customer_id` | `customers ||--o{ reviews` |
| 8 | books → reviews | **1:N** | `reviews.book_id` | `books ||--o{ reviews` |

### Referential actions summary
| Child FK | Parent | ON DELETE | ON UPDATE | Reason |
|---|---|---|---|---|
| books.publisher_id | publishers | RESTRICT | CASCADE | Cannot delete a publisher that still has books |
| book_authors.* / book_categories.* | books, authors, categories | CASCADE | CASCADE | Link rows are meaningless without parents |
| categories.parent_category_id | categories | SET NULL | CASCADE | Child becomes a top-level category |
| orders.customer_id | customers | RESTRICT | CASCADE | Keep order history |
| order_items.order_id | orders | CASCADE | CASCADE | Deleting an order deletes its items |
| order_items.book_id | books | RESTRICT | CASCADE | Keep sales history |
| reviews.book_id / customer_id | books, customers | CASCADE | CASCADE | Reviews depend on both |

---

## 4. 3NF Example (to point at in the video)

**Publisher information.** If `books` stored `publisher_name`, `publisher_address` and `publisher_website`, then those would depend on `publisher_id` (a non-key column), which is a **transitive dependency** `book_id → publisher_id → publisher_address`. The design removes this by moving publisher data into `publishers` and keeping only the FK `books.publisher_id`.

**Junction tables.** `book_authors` has composite PK `(book_id, author_id)`. Its only extra column, `author_order`, depends on the **whole** key, so there is no partial dependency (2NF).
