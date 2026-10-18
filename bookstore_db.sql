-- =====================================================================
-- bookstore_db.sql  |  Homework 6 - Online Bookstore Database
-- =====================================================================

/* =====================================================================
   NORMALIZATION EXPLANATION (how this design reaches 3NF)
   ---------------------------------------------------------------------
   1NF - Atomic values, no repeating groups
     * Every column holds a single value. A book's several authors are NOT
       stored as "Author1, Author2" in books; they live as separate rows
       in book_authors. Same for categories (book_categories) and for the
       items of an order (order_items).
     * Names are split (first_name / last_name); addresses are split into
       address, city, postal_code, country.
     * Every table has a primary key.

   2NF - No partial dependencies
     * All entity tables use a single-column surrogate PK (AUTO_INCREMENT),
       so a partial dependency is impossible.
     * Junction tables book_authors(book_id, author_id) and
       book_categories(book_id, category_id) have composite PKs. Their only
       non-key column (author_order) depends on the WHOLE key
       (the position of THIS author on THIS book). Author name, book title,
       etc. are NOT repeated there.
     * order_items has surrogate PK + UNIQUE(order_id, book_id);
       quantity and unit_price depend on the whole (order, book) pair.

   3NF - No transitive dependencies
     * Publisher data (address, website...) is stored once in publishers;
       books only keeps publisher_id (book -> publisher_id -> publisher info
       is moved out instead of being repeated in each book row).
     * Category hierarchy is stored via parent_category_id (self reference),
       not by repeating parent names.
     * Customer info lives only in customers; orders keeps customer_id.
     * Author info lives only in authors.
     * order_items.subtotal is a GENERATED column (quantity * unit_price),
       so it can never become inconsistent.

   Deliberate, documented "snapshot" columns (not 3NF violations):
     * order_items.unit_price: price of the book AT PURCHASE TIME. It
       depends on the order line (a historical fact), not on books.price,
       which can change later.
     * orders.shipping_*: the address used for THAT order. A customer may
       move later, so it must not be derived from customers.
     * orders.total_amount: required by the assignment as part of the order
       header. It is a snapshot of SUM(order_items.subtotal) at checkout;
       the verification query at the end of this file proves it matches.
   ===================================================================== */

DROP DATABASE IF EXISTS bookstore_db;
CREATE DATABASE bookstore_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE bookstore_db;

SET NAMES utf8mb4;

-- =====================================================================
-- 1. TABLES
-- =====================================================================

CREATE TABLE authors (
  author_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name  VARCHAR(100) NOT NULL,
  last_name   VARCHAR(100) NOT NULL,
  biography   TEXT NULL,
  nationality VARCHAR(60) NULL,
  birth_date  DATE NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (author_id),
  INDEX idx_authors_last_name (last_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE publishers (
  publisher_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name         VARCHAR(150) NOT NULL,
  address      VARCHAR(255) NULL,
  city         VARCHAR(100) NULL,
  country      VARCHAR(100) NULL,
  website      VARCHAR(255) NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (publisher_id),
  UNIQUE KEY uq_publishers_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categories (
  category_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name               VARCHAR(100) NOT NULL,
  description        VARCHAR(255) NULL,
  parent_category_id INT UNSIGNED NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_categories_name (name),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_category_id) REFERENCES categories (category_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE books (
  book_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  isbn             CHAR(13) NOT NULL,
  title            VARCHAR(255) NOT NULL,
  publisher_id     INT UNSIGNED NOT NULL,
  price            DECIMAL(10,2) NOT NULL,
  stock_quantity   INT NOT NULL DEFAULT 0,
  publication_date DATE NULL,
  pages            SMALLINT UNSIGNED NULL,
  language         VARCHAR(30) NOT NULL DEFAULT 'English',
  description      TEXT NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (book_id),
  UNIQUE KEY uq_books_isbn (isbn),
  INDEX idx_books_title (title),
  CONSTRAINT chk_books_price CHECK (price > 0),
  CONSTRAINT chk_books_stock CHECK (stock_quantity >= 0),
  CONSTRAINT chk_books_pages CHECK (pages IS NULL OR pages > 0),
  CONSTRAINT fk_books_publisher
    FOREIGN KEY (publisher_id) REFERENCES publishers (publisher_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- M:N books <-> authors
CREATE TABLE book_authors (
  book_id      INT UNSIGNED NOT NULL,
  author_id    INT UNSIGNED NOT NULL,
  author_order TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (book_id, author_id),
  INDEX idx_book_authors_author (author_id),
  CONSTRAINT chk_book_authors_order CHECK (author_order >= 1),
  CONSTRAINT fk_book_authors_book
    FOREIGN KEY (book_id) REFERENCES books (book_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_book_authors_author
    FOREIGN KEY (author_id) REFERENCES authors (author_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- M:N books <-> categories
CREATE TABLE book_categories (
  book_id     INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (book_id, category_id),
  INDEX idx_book_categories_category (category_id),
  CONSTRAINT fk_book_categories_book
    FOREIGN KEY (book_id) REFERENCES books (book_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_book_categories_category
    FOREIGN KEY (category_id) REFERENCES categories (category_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE customers (
  customer_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone         VARCHAR(20) NULL,
  address       VARCHAR(255) NULL,
  city          VARCHAR(100) NULL,
  postal_code   VARCHAR(20) NULL,
  country       VARCHAR(100) NOT NULL DEFAULT 'Vietnam',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id),
  UNIQUE KEY uq_customers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE orders (
  order_id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id          INT UNSIGNED NOT NULL,
  order_date           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status               ENUM('pending','processing','shipped','delivered','cancelled')
                       NOT NULL DEFAULT 'pending',
  total_amount         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  shipping_address     VARCHAR(255) NOT NULL,
  shipping_city        VARCHAR(100) NOT NULL,
  shipping_postal_code VARCHAR(20) NULL,
  shipping_country     VARCHAR(100) NOT NULL DEFAULT 'Vietnam',
  PRIMARY KEY (order_id),
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_date (order_date),
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0),
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_items (
  order_item_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id      INT UNSIGNED NOT NULL,
  book_id       INT UNSIGNED NOT NULL,
  quantity      INT UNSIGNED NOT NULL DEFAULT 1,
  unit_price    DECIMAL(10,2) NOT NULL,
  subtotal      DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  PRIMARY KEY (order_item_id),
  UNIQUE KEY uq_order_items_order_book (order_id, book_id),
  INDEX idx_order_items_book (book_id),
  CONSTRAINT chk_order_items_qty CHECK (quantity > 0),
  CONSTRAINT chk_order_items_price CHECK (unit_price > 0),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_order_items_book
    FOREIGN KEY (book_id) REFERENCES books (book_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reviews (
  review_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  book_id     INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  rating      TINYINT UNSIGNED NOT NULL,
  comment     TEXT NULL,
  review_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  UNIQUE KEY uq_reviews_customer_book (customer_id, book_id),
  INDEX idx_reviews_book (book_id),
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT fk_reviews_book
    FOREIGN KEY (book_id) REFERENCES books (book_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reviews_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 2. SAMPLE DATA
-- =====================================================================

-- 8 authors
INSERT INTO authors (author_id, first_name, last_name, biography, nationality, birth_date) VALUES
(1, 'George',   'Orwell',    'English novelist and essayist known for sharp criticism of totalitarianism.', 'British',  '1903-06-25'),
(2, 'J.R.R.',   'Tolkien',   'English writer and philologist, creator of Middle-earth.',                    'British',  '1892-01-03'),
(3, 'Frank',    'Herbert',   'American science fiction author best known for the Dune saga.',               'American', '1920-10-08'),
(4, 'Yuval Noah','Harari',   'Historian and professor at the Hebrew University of Jerusalem.',              'Israeli',  '1976-02-24'),
(5, 'Martin',   'Kleppmann', 'Researcher and author focused on distributed systems and data.',              'British',  NULL),
(6, 'Robert C.','Martin',    'Software engineer and author known as "Uncle Bob".',                          'American', '1952-12-05'),
(7, 'Andrew',   'Hunt',      'Software developer and co-author of The Pragmatic Programmer.',               'American', NULL),
(8, 'David',    'Thomas',    'Software developer and co-author of The Pragmatic Programmer.',               'British',  NULL);

-- 4 publishers
INSERT INTO publishers (publisher_id, name, address, city, country, website) VALUES
(1, 'Penguin Random House', '1745 Broadway',              'New York',  'USA', 'https://www.penguinrandomhouse.com'),
(2, 'HarperCollins',        '195 Broadway',               'New York',  'USA', 'https://www.harpercollins.com'),
(3, 'O''Reilly Media',      '1005 Gravenstein Hwy North', 'Sebastopol','USA', 'https://www.oreilly.com'),
(4, 'Pearson Education',    '221 River Street',           'Hoboken',   'USA', 'https://www.pearson.com');

-- 5 categories (parents inserted first because of the self-reference)
INSERT INTO categories (category_id, name, description, parent_category_id) VALUES
(1, 'Fiction',         'Novels and imaginative storytelling',        NULL),
(2, 'Non-Fiction',     'Factual and educational books',              NULL),
(3, 'Science Fiction', 'Speculative futures and science themes',     1),
(4, 'Fantasy',         'Magic, myth and imaginary worlds',           1),
(5, 'Technology',      'Software, computing and engineering',        2);

-- 8 books
INSERT INTO books (book_id, isbn, title, publisher_id, price, stock_quantity, publication_date, pages, language, description) VALUES
(1, '9780451524935', '1984',                                   1,  9.99, 50, '1949-06-08', 328, 'English', 'Dystopian novel about surveillance and control.'),
(2, '9780451526342', 'Animal Farm',                            1,  8.49, 40, '1945-08-17', 112, 'English', 'Allegorical novella about a farm revolution.'),
(3, '9780261102217', 'The Hobbit',                             2, 12.99, 35, '1937-09-21', 310, 'English', 'Bilbo Baggins joins a quest to reclaim a treasure.'),
(4, '9780441013593', 'Dune',                                   1, 14.99, 28, '1965-08-01', 688, 'English', 'Epic of politics and ecology on the desert planet Arrakis.'),
(5, '9780062316097', 'Sapiens: A Brief History of Humankind',  2, 18.50, 60, '2015-02-10', 464, 'English', 'A sweeping history of the human species.'),
(6, '9781449373320', 'Designing Data-Intensive Applications',  3, 45.00, 20, '2017-03-16', 616, 'English', 'Principles behind reliable, scalable data systems.'),
(7, '9780132350884', 'Clean Code',                            4, 39.99, 25, '2008-08-01', 464, 'English', 'A handbook of agile software craftsmanship.'),
(8, '9780135957059', 'The Pragmatic Programmer',               4, 42.50, 18, '2019-09-13', 352, 'English', 'Practical advice for software developers (20th anniversary ed.).');

-- book_authors (M:N) - Pragmatic Programmer has 2 authors
INSERT INTO book_authors (book_id, author_id, author_order) VALUES
(1, 1, 1), (2, 1, 1), (3, 2, 1), (4, 3, 1),
(5, 4, 1), (6, 5, 1), (7, 6, 1),
(8, 7, 1), (8, 8, 2);

-- book_categories (M:N)
INSERT INTO book_categories (book_id, category_id) VALUES
(1, 1), (1, 3),
(2, 1),
(3, 1), (3, 4),
(4, 1), (4, 3),
(5, 2),
(6, 2), (6, 5),
(7, 2), (7, 5),
(8, 2), (8, 5);

-- 5 customers (password_hash values are sample placeholders of bcrypt length)
INSERT INTO customers (customer_id, first_name, last_name, email, password_hash, phone, address, city, postal_code, country) VALUES
(1, 'An',   'Nguyen Van', 'an.nguyen@example.com',  '$2y$10$N9qo8uLOickgx2ZMRZoMyeIjZAdbS8Z9sdW3pPzGZnMOSyU2JB5me', '0901234567', '12 Hang Bai Street',      'Hanoi',        '100000', 'Vietnam'),
(2, 'Binh', 'Tran Thi',   'binh.tran@example.com',  '$2y$10$Q1w2E3r4T5y6U7i8O9p0AuBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeF', '0912345678', '45 Nguyen Hue Boulevard', 'Ho Chi Minh City','700000','Vietnam'),
(3, 'Chau', 'Le Minh',    'chau.le@example.com',    '$2y$10$ZxCvBnMaSdFgHjKlQwErTyUiOpAsDfGhJkLzXcVbNmQwErTyUiOpA', '0923456789', '8 Bach Dang Street',      'Da Nang',      '550000', 'Vietnam'),
(4, 'Dung', 'Pham Quoc',  'dung.pham@example.com',  '$2y$10$PoIuYtReWqAsDfGhJkLmNbVcXzQwErTyUiOpLkJhGfDsAzXcVbNmQ', '0934567890', '27 Tran Phu Street',     'Hai Phong',    '180000', 'Vietnam'),
(5, 'Ha',   'Hoang Thu',  'ha.hoang@example.com',   '$2y$10$MnBvCxZlKjHgFdSaPoIuYtReWqLkJhGfDsAzXcVbNmQwErTyUiOpA', '0945678901', '99 Le Loi Street',        'Hue',          '530000', 'Vietnam');

-- 6 orders (total_amount = sum of its items, see verification query below)
INSERT INTO orders (order_id, customer_id, order_date, status, total_amount, shipping_address, shipping_city, shipping_postal_code, shipping_country) VALUES
(1, 1, '2025-01-15 09:30:00', 'delivered',  69.98, '12 Hang Bai Street',      'Hanoi',          '100000', 'Vietnam'),
(2, 2, '2025-02-03 14:10:00', 'shipped',    49.99, '45 Nguyen Hue Boulevard', 'Ho Chi Minh City','700000', 'Vietnam'),
(3, 3, '2025-02-20 11:45:00', 'delivered',  82.49, '8 Bach Dang Street',      'Da Nang',        '550000', 'Vietnam'),
(4, 4, '2025-03-05 16:20:00', 'pending',    35.46, '27 Tran Phu Street',      'Hai Phong',      '180000', 'Vietnam'),
(5, 1, '2025-03-18 08:05:00', 'processing', 61.47, '12 Hang Bai Street',      'Hanoi',          '100000', 'Vietnam'),
(6, 5, '2025-03-25 19:40:00', 'cancelled',  87.50, '99 Le Loi Street',        'Hue',            '530000', 'Vietnam');

-- 14 order items (subtotal is generated automatically)
INSERT INTO order_items (order_id, book_id, quantity, unit_price) VALUES
(1, 1, 1,  9.99),
(1, 4, 1, 14.99),
(1, 6, 1, 45.00),
(2, 5, 2, 18.50),
(2, 3, 1, 12.99),
(3, 7, 1, 39.99),
(3, 8, 1, 42.50),
(4, 2, 3,  8.49),
(4, 1, 1,  9.99),
(5, 3, 1, 12.99),
(5, 5, 1, 18.50),
(5, 4, 2, 14.99),
(6, 6, 1, 45.00),
(6, 8, 1, 42.50);

-- 10 reviews (one per customer per book)
INSERT INTO reviews (book_id, customer_id, rating, comment, review_date) VALUES
(1, 1, 5, 'Chilling and still relevant today.',                 '2025-01-25 10:00:00'),
(4, 1, 5, 'A masterpiece of world-building.',                   '2025-01-28 21:15:00'),
(5, 2, 4, 'Fascinating, though some chapters are long.',        '2025-02-12 13:30:00'),
(3, 2, 5, 'Perfect adventure story.',                           '2025-02-14 09:20:00'),
(7, 3, 4, 'Great principles, a few examples feel dated.',       '2025-03-01 18:00:00'),
(8, 3, 5, 'Changed how I think about my daily coding habits.',  '2025-03-03 20:45:00'),
(2, 4, 4, 'Short, sharp and unforgettable.',                    '2025-03-10 12:10:00'),
(1, 4, 4, 'Heavy but important read.',                          '2025-03-11 15:25:00'),
(6, 1, 5, 'The best book on data systems I have read.',         '2025-03-20 22:00:00'),
(4, 5, 5, 'Read it twice, loved it both times.',                '2025-03-26 08:30:00');

-- =====================================================================
-- 3. VERIFICATION QUERIES (optional - useful for the demo video)
-- =====================================================================

SHOW TABLES;

SELECT 'authors' AS tbl, COUNT(*) AS row_count FROM authors
UNION ALL SELECT 'publishers',      COUNT(*) FROM publishers
UNION ALL SELECT 'categories',      COUNT(*) FROM categories
UNION ALL SELECT 'books',           COUNT(*) FROM books
UNION ALL SELECT 'book_authors',    COUNT(*) FROM book_authors
UNION ALL SELECT 'book_categories', COUNT(*) FROM book_categories
UNION ALL SELECT 'customers',       COUNT(*) FROM customers
UNION ALL SELECT 'orders',          COUNT(*) FROM orders
UNION ALL SELECT 'order_items',     COUNT(*) FROM order_items
UNION ALL SELECT 'reviews',         COUNT(*) FROM reviews;

-- Every order's total_amount must equal the sum of its items (expect 0 mismatches)
SELECT o.order_id, o.total_amount, SUM(oi.subtotal) AS items_sum
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.subtotal);
