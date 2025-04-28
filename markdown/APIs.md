# APIs 
This is the list of APIs that will be used for this solution and it contains details about the APIs and what's needed to use these APIs.

## Smart Address Validation
This operation validates addresses to improve postal accuracy within the country (e.g., United States). This ensure that parcels are rated correctly and shipments reach their final destination on time. The validate address operation sends an address for verification, and the response indicates whether the address is valid.
- [addressValidate](https://docs.shipping360.pitneybowes.com/openapi/address/operation/addressValidate/)

## Cost Optimized Carrie Rate Selection
This API contains 2 operations, rate shop and single rate. Rate shop will fetch rates for all carrier services based on the given addresses (From and To), weight, and dimension for given parcelType. If parcelType is not provided, it will default to PKG. Single rate will get rate for specific service and special service (if requested) based on the given addresses (From and To), weight, and dimension, parcelType and serviceId with or without specialServices. Single rate will be used mainly to a rate a shipment before creating shipment.
- [getRates](https://docs.shipping360.pitneybowes.com/openapi/shipping/operation/getRates/)

## Label Printing & Tracking

### Create Shipment
The operation creates a new Shipment or generate a Shipment Label. Here, Shipment refers to process where an item is packed and shipped from one point (source) to the other (destination) using some carrier service. This operation is also used to generate a return shipment label.
- [createShipment](https://docs.shipping360.pitneybowes.com/openapi/shipping/operation/createShipment/)

### Get Shipment Tracking Details
  Used to get tracking details.
- [getShipmentTrackingDetails](https://docs.shipping360.pitneybowes.com/openapi/tracking/operation/getShipmentTrackingDetails/)

## Post-Purchase Experience
TBD - Waiting for details from customer.

## Carrier Selection
Will need to call the getRates API to get cheapest and fastest rates, then user will need to select the best option. See the ### Create Shipment and `getRates` API.
