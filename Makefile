# EazyVault build & deploy targets
#
# Projects come from .firebaserc aliases: dev = eazy-vault-dev,
# prod = eazy-vault-prod. Each env builds with its own entry point
# (lib/main_dev.dart / lib/main_prod.dart) pinned to that project.
#
# Common usage:
#   make deploy-dev            # build (main_dev) + deploy everything to dev
#   make deploy-prod           # build (main_prod) + deploy everything to prod
#   make deploy-prod-rules     # firestore.rules only, to prod
#   make deploy-dev-indexes    # firestore indexes only, to dev
#   make deploy-prod-hosting   # rebuild + hosting only, to prod

.PHONY: help \
	build-dev build-prod \
	deploy-dev deploy-prod \
	deploy-dev-rules deploy-dev-indexes deploy-dev-hosting deploy-dev-storage \
	deploy-prod-rules deploy-prod-indexes deploy-prod-hosting deploy-prod-storage

help:
	@echo "build-dev / build-prod          - flutter build web for each env"
	@echo "deploy-dev / deploy-prod        - build + deploy hosting, rules, indexes"
	@echo "deploy-<env>-rules             - firestore.rules only"
	@echo "deploy-<env>-indexes           - firestore.indexes.json only"
	@echo "deploy-<env>-hosting           - build + hosting only"
	@echo "deploy-<env>-storage           - storage.rules only (needs Storage set up in console)"

# --pwa-strategy=none: no service-worker caching, so a deploy always serves
# the fresh bundle (avoids stale builds pointing at the wrong Firebase project).
build-dev:
	flutter build web --release --pwa-strategy=none -t lib/main_dev.dart

build-prod:
	flutter build web --release --pwa-strategy=none -t lib/main_prod.dart

deploy-dev: build-dev
	firebase deploy --only hosting,firestore --project dev

deploy-prod: build-prod
	firebase deploy --only hosting,firestore --project prod

deploy-dev-rules:
	firebase deploy --only firestore:rules --project dev

deploy-dev-indexes:
	firebase deploy --only firestore:indexes --project dev

deploy-dev-hosting: build-dev
	firebase deploy --only hosting --project dev

deploy-dev-storage:
	firebase deploy --only storage --project dev

deploy-prod-rules:
	firebase deploy --only firestore:rules --project prod

deploy-prod-indexes:
	firebase deploy --only firestore:indexes --project prod

deploy-prod-hosting: build-prod
	firebase deploy --only hosting --project prod

deploy-prod-storage:
	firebase deploy --only storage --project prod
