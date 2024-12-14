#!/bin/bash

split_text() {
    local input="$1"
    local n="$2"
    local chunk=""

    while [[ ${#input} -gt 0 ]]; do
        # Extract up to n characters
        chunk="${input:0:n}"

        if [[ ${#input} -le $n ]]; then
            echo "$input"
            break
        fi

        # Find the last space within the chunk
        if [[ ${#chunk} -lt $n || $chunk == *" "* ]]; then
            last_space=$(echo "$chunk" | awk -v n="$n" '{print substr($0, 1, n)}' | awk -F" " '{print length($0)-length($NF)}')
            chunk=${chunk:0:last_space}
        fi

        # Print the chunk and trim the input
        echo "$chunk"
        input="${input:${#chunk}}"
        input=${input#" "} # Remove leading space
    done
}

# Input file containing the list of chapters
input_file="notes.txt"

# Temporary file to store the modified list
temp_file=$(mktemp)

# Process each line in the input file
while IFS= read -r filename || [[ -n "$filename" ]]; do
    # Extract the base name and the extension
    base_name="${filename%.*}"
    # Create the modified filename
    long_filename="${base_name}-long.md"
    write_long=false
    if [[ ! -f "$long_filename" ]]; then
        {
            write_long=true
        }
    else
        {
            first_line=$(head -n 1 "$long_filename")
            if [[ "$first_line" == "<!--AUTOMATICALLY GENERATED" ]]; then
                {
                    write_long=true
                }
            fi
        }
    fi

    if $write_long; then
        {
            # Add comments to indicate automatic generation and source
            box_width=70
            padding=4
            max_row_length=$((box_width - 2 * padding))

            # Define the two rows inside the box
            text="This file was automatically generated by copying '$filename'. If you want to manually overwrite it, you have to remove this whole comment. Otherwise, it will be overwritten the next time any change happens in the notes."

            # Split the text in multiple lines
            mapfile -t rows < <(split_text "$text" $max_row_length)

            # Top border of the box
            printf "%s\n" "<!--AUTOMATICALLY GENERATED"
            printf "%*s\n" $box_width | tr " " "*"
            printf "*%*s*\n" $((box_width - 2)) " "
            for row in "${rows[@]}"; do
                printf "*%*s%s%*s*\n" "$padding" "" "$row" $((box_width - 2 - ${#row} - padding)) ""
            done
            printf "*%*s*\n" $((box_width - 2)) " "
            printf "%*s\n" $box_width | tr " " "*"
            printf "%s\n\n" "-->"

            # Append the original file's content
            cat "$filename"
        } >"$long_filename"
    fi
    echo "$long_filename" >>"$temp_file"
done <"$input_file"

# Run Pandoc with the modified list of files
mkdir -p pdf
pandoc --from=markdown+rebase_relative_paths -s -o pdf/notes-long.pdf --metadata-file=metadata.yaml --toc --pdf-engine=pdflatex $(cat "$temp_file")

# Clean up the temporary file
rm "$temp_file"

echo "Long Markdown and PDF versions generated successfully!"
