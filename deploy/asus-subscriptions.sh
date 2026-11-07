#!/bin/sh
# Called by yaml_editpath before MerlinClash computes provider cache paths.
set -eu
config=$1
secrets=/jffs/local-subscriptions/providers.yaml
yq=/koolshare/bin/yq
[ -r "$secrets" ] || { printf '%s\n' 'Local subscriptions missing' >&2; exit 1; }
for name in vip1 vip2 vip3; do
    [ "$("$yq" ".proxy-providers | has(\"$name\")" "$config")" = true ] || continue
    PROVIDER="$name" "$yq" -o=yaml -e '.[strenv(PROVIDER)] | test("^https://")' "$secrets" >/dev/null || {
        printf 'Missing local subscription: %s\n' "$name" >&2
        exit 1
    }
done
for name in vip1 vip2 vip3; do
    [ "$("$yq" ".proxy-providers | has(\"$name\")" "$config")" = true ] || continue
    PROVIDER="$name" "$yq" -i '.proxy-providers[strenv(PROVIDER)].url = load("/jffs/local-subscriptions/providers.yaml")[strenv(PROVIDER)]' "$config"
done
