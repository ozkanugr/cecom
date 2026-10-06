#!/usr/bin/env bash
# Detects the project profile used to select applicable checks.
#
#   detect_profile.sh [project-dir]
#
# Prints one "tag: reason" line per detected tag, then "PROFILE=<comma-separated tags>".
# Tags: mobile web api db push pay llm. Read-only; heuristic — confirm with the user.
# Works with macOS's stock bash 3.2 (no associative arrays, no mapfile).
set -uo pipefail

DIR="${1:-.}"
[ -d "$DIR" ] || { echo "error: not a directory: $DIR" >&2; exit 2; }
cd "$DIR" || exit 2

TAGS=""
add() { # add <tag> <reason>
  case " $TAGS " in *" $1 "*) return 0 ;; esac
  TAGS="$TAGS $1"
  printf '%s: %s\n' "$1" "$2"
}

# Dependency manifests (root and one level down, e.g. ios/Podfile, app/build.gradle).
MANIFESTS=""
for f in package.json */package.json pubspec.yaml Podfile */Podfile Podfile.lock */Podfile.lock Package.swift \
         build.gradle build.gradle.kts app/build.gradle app/build.gradle.kts android/app/build.gradle \
         requirements.txt pyproject.toml Pipfile go.mod Gemfile composer.json Cargo.toml; do
  case "$f" in node_modules/*) continue ;; esac
  [ -f "$f" ] && MANIFESTS="$MANIFESTS $f"
done

dep() { # dep <extended-regex> → true if any manifest mentions it as a whole name (case-insensitive)
  [ -n "$MANIFESTS" ] || return 1
  # shellcheck disable=SC2086
  grep -qsiE "(^|[^a-z0-9_])($1)" $MANIFESTS
}

any_exists() { # any_exists <glob...> → true if at least one pattern matches an existing path
  for p in "$@"; do [ -e "$p" ] && return 0; done
  return 1
}

find_named() { # find_named <name-pattern...> → true if a file/dir with that name exists within 4 levels
  for n in "$@"; do
    if find . -maxdepth 4 \( -path '*/node_modules' -o -path '*/.git' -o -path '*/Pods' -o -path '*/build' \) -prune \
         -o -name "$n" -print 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

src_has() { # src_has <extended-regex> <glob...> → true if any source file matches
  local re="$1"; shift
  local inc=""
  for g in "$@"; do inc="$inc --include=$g"; done
  # shellcheck disable=SC2086
  grep -rqsE $inc --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=Pods \
    --exclude-dir=build --exclude-dir=dist --exclude-dir=.build --exclude-dir=DerivedData \
    "$re" . 2>/dev/null
}

# --- mobile
if find_named '*.xcodeproj' '*.xcworkspace'; then add mobile "Xcode project"
elif find_named AndroidManifest.xml; then add mobile "Android app module"
elif [ -f pubspec.yaml ] && grep -qs 'flutter' pubspec.yaml; then add mobile "Flutter (pubspec.yaml)"
elif dep '"(react-native|expo)"'; then add mobile "React Native / Expo dependency"
elif [ -f Package.swift ] && grep -qsE '\.iOS|\.macOS|\.watchOS|\.visionOS' Package.swift; then add mobile "Swift package for Apple platforms"
fi

# --- web
if dep '"(react-dom|next|vue|nuxt|svelte|@sveltejs/kit|@angular/core|solid-js|astro|@remix-run/react|preact)"'; then
  add web "browser framework dependency"
elif [ -f index.html ] || [ -f public/index.html ] || [ -f src/index.html ]; then
  add web "index.html"
fi

# --- api
if dep '"(express|fastify|koa|hono|@nestjs/core|@trpc/server|apollo-server|@apollo/server|next)"' \
   || dep '(django|flask|fastapi|starlette|rails|sinatra|laravel/framework|gin-gonic|gofiber|labstack/echo|actix-web|axum|spring-boot)'; then
  add api "server framework dependency"
elif [ -d supabase ] || [ -f firebase.json ] || [ -f firestore.rules ]; then
  add api "BaaS project files (Supabase/Firebase)"
elif [ -d api ] || [ -d server ] || [ -d functions ] || [ -d netlify/functions ] || [ -f vercel.json ]; then
  add api "server/functions directory"
fi

# --- db
if dep '"(prisma|@prisma/client|drizzle-orm|typeorm|sequelize|mongoose|mongodb|knex|pg|mysql2|better-sqlite3|@supabase/supabase-js|firebase|firebase-admin|realm|@nozbe/watermelondb|expo-sqlite|react-native-mmkv)"' \
   || dep '(sqlalchemy|psycopg|django|activerecord|gorm|room-runtime|sqflite|drift|hive|isar|GRDB|SQLite\.swift|RealmSwift)'; then
  add db "database/ORM dependency"
elif [ -d migrations ] || [ -d prisma ] || [ -d supabase/migrations ] || [ -d db/migrate ]; then
  add db "migrations directory"
elif find_named '*.xcdatamodeld' || src_has 'import SwiftData|@Model' '*.swift'; then
  add db "Core Data / SwiftData model"
fi

# --- push
if dep '(firebase-messaging|@react-native-firebase/messaging|expo-notifications|onesignal|react-native-push-notification|@notifee|firebase_messaging|pusher-beams)'; then
  add push "push notification SDK"
elif src_has 'registerForRemoteNotifications|UNUserNotificationCenter|FirebaseMessagingService' '*.swift' '*.m' '*.kt' '*.java'; then
  add push "native push registration code"
fi

# --- pay
if dep '(stripe|react-native-purchases|purchases_flutter|RevenueCat|revenuecat|braintree|paddle|lemonsqueezy|iyzipay|adyen|in_app_purchase|react-native-iap|expo-in-app-purchases|billingclient|com\.android\.billingclient)'; then
  add pay "payments/purchases SDK"
elif src_has 'import StoreKit|Product\.products|SKPaymentQueue' '*.swift'; then
  add pay "StoreKit code"
fi

# --- llm
if dep '(openai|@anthropic-ai/sdk|"anthropic"|langchain|@langchain|llamaindex|llama-index|@google/generative-ai|@google/genai|google-generativeai|"ai"|ollama|mistralai|cohere|groq-sdk|replicate)'; then
  add llm "LLM SDK dependency"
elif src_has 'api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis\.com' '*.ts' '*.tsx' '*.js' '*.py' '*.swift' '*.kt' '*.dart' '*.go'; then
  add llm "direct LLM API calls"
fi

PROFILE=$(printf '%s' "$TAGS" | sed 's/^ //; s/ /,/g')
[ -n "$PROFILE" ] || echo "note: nothing detected — ask the user which tags apply" >&2
echo "PROFILE=${PROFILE}"
