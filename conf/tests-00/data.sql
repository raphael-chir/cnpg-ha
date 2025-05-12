CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    stock INT NOT NULL DEFAULT 0
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    total_price NUMERIC(10,2),
    ordered_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO customers (name, email, created_at) VALUES
('Alice Martin', 'alice@example.com', now() - interval '2 days'),
('Bob Dupont', 'bob@example.com', now() - interval '1 day');

INSERT INTO products (name, price, stock) VALUES
('Keyboard', 79.99, 100),
('Screen', 249.90, 50),
('Mouse', 29.99, 200);

INSERT INTO orders (customer_id, product_id, quantity, total_price, ordered_at) VALUES
(1, 1, 2, 2 * 79.99, now() - interval '1 day'),
(2, 2, 1, 1 * 249.90, now() - interval '12 hours'),
(1, 3, 3, 3 * 29.99, now() - interval '1 hour');
