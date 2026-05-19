.PHONY: gen check rust-test no-placeholders rust-validation

gen:
	./scripts/gen.sh

check:
	./scripts/check.sh

rust-test:
	cd rust && cargo test

no-placeholders:
	./scripts/check-no-placeholders.sh

rust-validation:
	./scripts/check-rust-validation.sh
