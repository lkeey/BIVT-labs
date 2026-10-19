#!/usr/bin/env bash
# Read-only preflight for docs/azure-mi-free.md. This script creates no resources.
set -euo pipefail

: "${COURSEWORK_SUBSCRIPTION_ID:?Set COURSEWORK_SUBSCRIPTION_ID}"
: "${COURSEWORK_LOCATION:?Set COURSEWORK_LOCATION}"

if ! command -v az >/dev/null 2>&1; then
  printf 'Azure CLI (az) is not installed.\n' >&2
  exit 1
fi

case "$COURSEWORK_LOCATION" in
  *[!a-z0-9]*|'')
    printf 'COURSEWORK_LOCATION must be an Azure region name, for example eastus.\n' >&2
    exit 1
    ;;
esac

current_subscription="$(az account show --query id --output tsv)"
if [[ "$current_subscription" != "$COURSEWORK_SUBSCRIPTION_ID" ]]; then
  printf 'Selected subscription differs from COURSEWORK_SUBSCRIPTION_ID.\n' >&2
  exit 1
fi

account_state="$(az account show --query state --output tsv)"
if [[ "$account_state" != 'Enabled' ]]; then
  printf 'Azure subscription is not enabled: %s\n' "$account_state" >&2
  exit 1
fi

for provider in Microsoft.Sql Microsoft.Network; do
  state="$(az provider show --namespace "$provider" --query registrationState --output tsv)"
  if [[ "$state" != 'Registered' ]]; then
    printf '%s provider is not registered: %s\n' "$provider" "$state" >&2
    exit 1
  fi
done

region="$(az account list-locations \
  --query "[?name=='${COURSEWORK_LOCATION}'].name | [0]" --output tsv)"
if [[ "$region" != "$COURSEWORK_LOCATION" ]]; then
  printf 'Region %s is not visible in the selected subscription.\n' "$COURSEWORK_LOCATION" >&2
  exit 1
fi

cli_help="$(az sql mi create --help)"
for required in '--pricing-model' 'Freemium' '--database-format' 'SQLServer2025'; do
  if [[ "$cli_help" != *"$required"* ]]; then
    printf 'Azure CLI does not advertise %s; update az before provisioning.\n' "$required" >&2
    exit 1
  fi
done

existing_free="$(az sql mi list --subscription "$COURSEWORK_SUBSCRIPTION_ID" \
  --query "[?pricingModel=='Freemium'].name" --output tsv)"
if [[ -n "$existing_free" ]]; then
  printf 'A Freemium SQL Managed Instance already exists in this subscription:\n%s\n' \
    "$existing_free" >&2
  exit 1
fi

printf 'Read-only checks passed for subscription %s in %s.\n' \
  "$COURSEWORK_SUBSCRIPTION_ID" "$COURSEWORK_LOCATION"
printf 'Azure still decides Freemium eligibility at creation; review the Portal cost summary.\n'
