from __future__ import annotations

import argparse
import sys

from src.auth.session import direct_session
from src.crawler.subject_discovery import discover_subjects
from src.crawler.syllabus_detail import download_syllabus_detail_via_cdp, download_syllabus_details
from src.crawler.syllabus_index import discover_syllabi
from src.exporter.obsidian import export_obsidian
from src.graph.builder import build_graph
from src.indexer.sqlite_indexer import build_sqlite
from src.parser.syllabus_parser import normalize_all


def main() -> None:
    parser = argparse.ArgumentParser(description="FLM local knowledge pipeline")
    subparsers = parser.add_subparsers(dest="command", required=True)
    detail_cdp = subparsers.add_parser("detail-cdp")
    detail_cdp.add_argument("syllabus_id", type=int)
    detail_cdp.add_argument("--cdp-url", default="http://localhost:9222")
    subparsers.add_parser("subjects")
    subparsers.add_parser("syllabi")
    subparsers.add_parser("download")
    subparsers.add_parser("normalize")
    subparsers.add_parser("graph")
    subparsers.add_parser("obsidian")
    subparsers.add_parser("sqlite")
    subparsers.add_parser("build-all")
    full_crawl = subparsers.add_parser("full-crawl")
    full_crawl.add_argument("--resume", action="store_true")
    full_crawl.add_argument("--raw-fetch-only", action="store_true")
    full_crawl.add_argument("--normalize-only", action="store_true")
    full_crawl.add_argument("--delay", type=float, default=3.0)
    full_crawl.add_argument("--retries", type=int, default=3)
    full_crawl.add_argument("--cdp-url", default="http://localhost:9222")
    args = parser.parse_args()

    if args.command == "detail-cdp":
        print(download_syllabus_detail_via_cdp(args.syllabus_id, cdp_url=args.cdp_url))
        return

    if args.command == "full-crawl":
        from scripts.full_active_crawl import main as full_crawl_main

        sys.argv = [
            sys.argv[0],
            "--cdp-url",
            args.cdp_url,
            "--delay",
            str(args.delay),
            "--retries",
            str(args.retries),
        ]
        if args.resume:
            sys.argv.append("--resume")
        if args.raw_fetch_only:
            sys.argv.append("--raw-fetch-only")
        if args.normalize_only:
            sys.argv.append("--normalize-only")
        full_crawl_main()
        return

    session = direct_session()
    if args.command == "subjects":
        discover_subjects(session)
    elif args.command == "syllabi":
        discover_syllabi(session)
    elif args.command == "download":
        download_syllabus_details(session)
    elif args.command == "normalize":
        normalize_all()
    elif args.command == "graph":
        build_graph()
    elif args.command == "obsidian":
        export_obsidian()
    elif args.command == "sqlite":
        build_sqlite()
    elif args.command == "build-all":
        discover_subjects(session)
        discover_syllabi(session)
        download_syllabus_details(session)
        normalize_all()
        build_graph()
        export_obsidian()
        build_sqlite()


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
