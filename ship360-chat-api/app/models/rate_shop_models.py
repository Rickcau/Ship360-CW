from pydantic import BaseModel, Field
from app.models.create_shipping_label_request import Address, Parcel, ShipmentOptions, MetadataItem

class RateShopRequest(BaseModel):
    dateOfShipment: str
    fromAddress: Address
    toAddress: Address
    parcel: Parcel
    parcelType: str