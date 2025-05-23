targetScope = 'resourceGroup'

#disable-next-line BCP081
resource bingAccount 'Microsoft.Bing/accounts@2025-05-01-preview' = {
  name: 'bing-ai-agent'
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

output bingAccountName string = bingAccount.name
