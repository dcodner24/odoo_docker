#!/usr/bin/env python3
import argparse
import os
import psycopg2
import sys
import time

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('--db_host', required=True)
    arg_parser.add_argument('--db_port', required=True)
    arg_parser.add_argument('--db_user', required=True)
    arg_parser.add_argument('--db_password', required=True)
    arg_parser.add_argument('--timeout', type=int, default=5)

    args = arg_parser.parse_args()

    db_name = os.getenv('POSTGRES_DB', 'postgres')  # Use the default database if not set

    print(f"Attempting to connect to database at {args.db_host}:{args.db_port} with user {args.db_user}")
    
    start_time = time.time()
    while (time.time() - start_time) < args.timeout:
        try:
            conn = psycopg2.connect(user=args.db_user, host=args.db_host, port=args.db_port,
                                    password=args.db_password, dbname=db_name)
            print("Successfully connected to the database")
            conn.close()
            sys.exit(0)
        except psycopg2.OperationalError as e:
            print(f"Failed to connect. Error: {e}")
        time.sleep(1)

    print(f"Database connection failure after {args.timeout} seconds", file=sys.stderr)
    sys.exit(1)
