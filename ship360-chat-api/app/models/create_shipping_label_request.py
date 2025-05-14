from pydantic import BaseModel, Field
from typing import List, Optional

class Address(BaseModel):
    company: str
    addressLine1: str
    addressLine2: Optional[str] = ""
    addressLine3: Optional[str] = ""
    cityTown: str
    countryCode: str
    name: str
    phone: str
    postalCode: str
    stateProvince: str

class Parcel(BaseModel):
    height: int
    length: int
    dimUnit: str
    width: int
    weightUnit: str
    weight: int

class ShipmentOptions(BaseModel):
    addToManifest: bool
    packageDescription: str

class MetadataItem(BaseModel):
    name: str
    value: str

class ShippingLabel(BaseModel):
    size: str
    type: str
    fromAddress: Address
    parcel: Parcel
    carrierAccountId: str
    parcelType: str
    serviceId: str
    shipmentOptions: ShipmentOptions
    metadata: List[MetadataItem]
    toAddress: Address