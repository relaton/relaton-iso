# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development

- `bin/setup` — install dependencies
- `rake spec` — run tests
- `rspec spec/relaton/iso/bibliography_spec.rb` — run a single test file
- `rspec spec/relaton/iso/bibliography_spec.rb -e "some description"` — run a specific example
- `rake spec:update_index` — download latest ISO index fixture (`spec/fixtures/index-v1.zip`) from relaton-data-iso
- `bin/console` — interactive prompt with the gem loaded
- `rubocop` — lint (Ribose OSS style guide, Ruby 3.2 target)

## Architecture

relaton-iso retrieves ISO standard bibliographic data. The core retrieval flow:

1. **Bibliography** (`lib/relaton/iso/bibliography.rb`) — entry point via `search(pubid)` and `get(ref, year, opts)`. Handles year filtering, part matching, and type/stage validation.
2. **HitCollection** (`lib/relaton/iso/hit_collection.rb`) — searches a pre-built YAML index (`index-v1.zip` from relaton-data-iso) using `Relaton::Index`. Matches on `id_keys`: publisher, number, copublisher, part, year, edition, type, stage, iteration. Returns sorted Hit array.
3. **Hit** (`lib/relaton/iso/hit.rb`) — wraps an index result. The `item` attribute lazy-loads the full document from GitHub raw content (relaton-data-iso repo). `sort_weight` prioritizes published over withdrawn/deleted.
4. **ItemData** / **Model::Item** — ISO-specific bibliographic item extending `Relaton::Bib::ItemData`.
5. **Scraper** (`lib/relaton/iso/scraper.rb`) — parses ISO website pages for metadata (used by DataFetcher for bulk operations, not the normal lookup path).
6. **DataFetcher** (`lib/relaton/iso/data_fetcher.rb`) — bulk fetches from ISO.org ICS pages using 3 threads with a persistent queue for resumability.

Key dependency: `pubid-iso` gem handles ISO publication identifier parsing and comparison.

## Testing

- **Framework:** RSpec with VCR cassettes and WebMock
- **Network access:** fully blocked via `WebMock.disable_net_connect!`
- **Index fixture:** `spec/fixtures/index-v1.zip` is served by WebMock stub (configured in `spec/support/webmock.rb`). Run `rake spec:update_index` to refresh when upstream data changes.
- **VCR:** cassettes in `spec/vcr_cassettes/`, record mode `:once`, re-record interval 7 days. Index download requests are ignored by VCR (handled by WebMock stub instead).
