set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_path> <output_path>" >&2
    exit 1
fi

input_path="$1"
output_path="$2"

if [ ! -d "$input_path" ]; then
    echo "Error: input path '$input_path' is not a directory" >&2
    exit 1
fi

mkdir -p "$output_path"

for f in "$input_path"/*; do
    [ -f "$f" ] || continue

    fname="$(basename "$f")"

    if [[ "$fname" =~ ([0-9]{4}) ]]; then
        year="${BASH_REMATCH[1]}"
        newname="${fname/$year/${year}0101-${year}1231}"
        target="$(realpath "$f")"
        linkpath="$output_path/$newname"

        ln -s "$target" "$linkpath"
        echo "Linked: $f -> $linkpath"
    else
        echo "Skipping (no year found): $f"
    fi
done
