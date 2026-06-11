export interface Pet {
  id: string
  name: string
  avatar: string
  type: 'cat' | 'dog'
}

export interface ServiceType {
  id: string
  name: string
  nameEn: string
  icon: 'cat' | 'dog'
}

export interface Address {
  id: string
  district: string
  detail: string
  contact: string
  phone: string
  isDefault: boolean
}

export interface VideoCheckpoint {
  id: string
  label: string
  icon: string
}

export interface OrderData {
  // Step 1
  selectedPets: string[]
  serviceType: string
  serviceDate: string
  serviceTime: string
  address: Address | null
  
  // Step 2
  keyLocation: string
  smartLockPassword: string
  foodLocation: string
  feedingAmount: string
  waterRequirement: string
  needPlayTime: boolean
  videoCheckpoints: VideoCheckpoint[]
  
  // Step 3
  baseFee: number
  playTimeFee: number
  holidayFee: number
}
