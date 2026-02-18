-- Database initialization script for chatapp
-- This script creates the database, user, and grants necessary privileges
-- run this on database: postgres
-- Create the database
CREATE DATABASE chatdb;

-- Create the application user
CREATE USER chatapp WITH PASSWORD 'YOUR_SECURE_PASSWORD';

-- Grant connection privileges
GRANT CONNECT ON DATABASE chatdb TO chatapp;

-- Grant all privileges on the database
GRANT ALL PRIVILEGES ON DATABASE chatdb TO chatapp;

-- Note: After connecting to the chatdb database, you may also need to grant schema privileges:
-- run this on database: chatdb
GRANT ALL PRIVILEGES ON SCHEMA public TO chatapp;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chatapp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO chatapp;

GRANT ALL ON SCHEMA public TO chatapp;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO chatapp;