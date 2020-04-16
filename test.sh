jobcount=$(curl -X GET https://api.github.com/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/jobs | jq .total_count)
echo "::add-mask::$jobcount"
