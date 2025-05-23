import { LucideIcon } from "lucide-react"

export interface ActionParameterOption {
  value: string;
  label: string;
}

export interface ActionParameter {
  name: string;
  label: string;
  placeholder: string;
  required: boolean;
  type?: 'text' | 'select' | 'checkbox';
  options?: ActionParameterOption[];
}

export interface Action {
  id: string;
  label: string;
  value: string;
  className: string;
  requiresParameters: boolean;
  icon: LucideIcon;
  tooltip: string;
  parameters?: ActionParameter[];
  promptTemplate: string;
}

export interface ActionData {
  vmName?: string;
  resourceGroup?: string;
  orderNumber?: string;
  deliverySpeed?: string;
  cheapestCarrier?: string;
  deliveryDate?: string;
  carrierService?: string;
  
  weightValue?: string;
  weightUnit?: string;
  length?: string;
  width?: string;
  height?: string;
  dimensionUnit?: string;
  
  fromAddress?: string;
  fromCity?: string;
  fromState?: string;
  fromZip?: string;
  
  toAddress?: string;
  toCity?: string;
  toState?: string;
  toZip?: string;
  
  countryCode?: string;
  
  weight?: string;
  dimensions?: string;
  
  [key: string]: string | undefined;
} 