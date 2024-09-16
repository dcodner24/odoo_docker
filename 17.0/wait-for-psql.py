#!/usr/bin/env python3
import argparse
import psycopg2
import sys
import time

def wait_for_postgres(db_host, db_port, db_user, db_password, db_name, timeout=30):
    start_time = time.time()

    while (time.time() - start_time) < timeout:
        try:
            conn = psycopg2.connect(
                dbname=db_name,
                user=db_user,
                password=db_password,
                host=db_host,
                port=db_port
            )
            conn.close()
            print("Successfully connected to the database")
            return True
        except psycopg2.OperationalError as e:
            print(f"Waiting for PostgreSQL to become available... ({e})")
            time.sleep(1)

    print(f"Could not connect to PostgreSQL within {timeout} seconds.", file=sys.stderr)
    return False

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Wait for PostgreSQL to become available')
    parser.add_argument('--db_host', required=True, help='Database host')
    parser.add_argument('--db_port', required=True, help='Database port')
    parser.add_argument('--db_user', required=True, help='Database user')
    parser.add_argument('--db_password', required=True, help='Database password')
    parser.add_argument('--db_name', required=True, help='Database name')
    parser.add_argument('--timeout', type=int, default=30, help='Timeout in seconds')

    args = parser.parse_args()

    if not wait_for_postgres(args.db_host, args.db_port, args.db_user, args.db_password, args.db_name, args.timeout):
        sys.exit(1)
