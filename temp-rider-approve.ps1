$api = 'http://localhost:4000/api'
$headers = @{ 'Content-Type' = 'application/json' }
$orderBody = @{ 
    items = @(@{ productId = 'p1'; quantity = 1; price = 1200 })
    orderType = 'Delivery'
    customerName = 'Test Rider'
    phone = '+923001234567'
    address = '123 Test Street'
    serviceType = 'Standard Delivery'
    deliveryFee = 50
    paymentMethod = 'Cash'
    status = 'Kitchen'
}
$order = Invoke-RestMethod -Uri "$api/pos/orders" -Method Post -Headers $headers -Body ($orderBody | ConvertTo-Json -Depth 5)
Write-Output "CREATE ORDER: $($order.id)"
$login = Invoke-RestMethod -Uri "$api/auth/login" -Method Post -Headers $headers -Body ((@{ email = 'admin@usmanhotel.com'; password = 'admin123' }) | ConvertTo-Json)
Write-Output 'ADMIN TOKEN OK'
$token = $login.token
$reqBody = @{ riderId = 'rider1'; orderId = $order.id }
$req = Invoke-RestMethod -Uri "$api/rider/request-approval" -Method Post -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } -Body ($reqBody | ConvertTo-Json)
Write-Output "REQUEST ID: $($req.id)"
Invoke-RestMethod -Uri "$api/rider/approve-request/$($req.id)" -Method Put -Headers @{ Authorization = "Bearer $token" }
Write-Output 'APPROVAL DONE'
$approvedOrders = Invoke-RestMethod -Uri "$api/rider/approved-orders/rider1" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Output "APPROVED ORDERS COUNT: $($approvedOrders.Count)"
$approvedOrders | ConvertTo-Json -Depth 5 | Write-Output
