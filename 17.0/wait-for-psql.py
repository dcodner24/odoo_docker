#!/usr/bin/env python3
import argparse
import psycopg2
import sys
import time

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('--db_host', required=True)
    arg_parser.add_argument('--db_port', required=True)
    arg_parser.add_argument('--db_user', required=True)
    arg_parser.add_argument('--db_password', required=True)
    arg_parser.add_argument('--database', required=True)
    arg_parser.add_argument('--timeout', type=int, default=30)

    args = arg_parser.parse_args()

    start_time = time.time()
    while (time.time() - start_time) < args.timeout:
        try:
            conn = psycopg2.connect(
                dbname=args.database,
                user=args.db_user,
                password=args.db_password,
                host=args.db_host,
                port=args.db_port
            )
            conn.close()
            print("Successfully connected to the database")
            sys.exit(0)
        except psycopg2.OperationalError as e:
            print(f"Waiting for PostgreSQL to become available... ({e})")
            time.sleep(1)

    print(f"Could not connect to PostgreSQL within {args.timeout} seconds.", file=sys.stderr)
    sys.exit(1)
