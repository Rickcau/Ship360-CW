from pydantic import BaseModel, Field
from typing import List, Optional
from create_shipping_label_request import Address, Parcel, ShipmentOptions, MetadataItem

class RateShopRequest(BaseModel):
    fromAddress: Address
    toAddress: Address
    parcel: Parcel
    parcelType: str
    serviceId: str