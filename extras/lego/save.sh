#!/bin/bash
cargo clean
cargo build
cargo run

/usr/local/bin/python3.10 /Users/trevor/trevorscholz1/extras/lego/save_sets.py
