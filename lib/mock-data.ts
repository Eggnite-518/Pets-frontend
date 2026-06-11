import type { Pet, ServiceType, Address, VideoCheckpoint, OrderData } from '@/types/order'

export const mockPets: Pet[] = [
  {
    id: '1',
    name: '咪咪',
    avatar: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=200&h=200&fit=crop',
    type: 'cat'
  },
  {
    id: '2',
    name: '大黄',
    avatar: 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=200&h=200&fit=crop',
    type: 'dog'
  }
]

export const serviceTypes: ServiceType[] = [
  {
    id: 'feeding',
    name: '上门喂猫',
    nameEn: 'Feeding & Care',
    icon: 'cat'
  },
  {
    id: 'walking',
    name: '上门遛狗',
    nameEn: 'Outdoor Walking',
    icon: 'dog'
  }
]

export const defaultAddress: Address = {
  id: '1',
  district: '上海市静安区',
  detail: '南京西路 1266 号恒隆广场 A 座 2805 室',
  contact: '王先生',
  phone: '138****0000',
  isDefault: true
}

export const defaultVideoCheckpoints: VideoCheckpoint[] = [
  { id: '1', label: '入门反馈', icon: 'door' },
  { id: '2', label: '添粮饮水', icon: 'food' },
  { id: '3', label: '清理留档', icon: 'clean' }
]

export const initialOrderData: OrderData = {
  selectedPets: [],
  serviceType: 'feeding',
  serviceDate: '2023年11月24日 (今日)',
  serviceTime: '14:00 - 15:00',
  address: defaultAddress,
  keyLocation: '',
  smartLockPassword: '',
  foodLocation: '厨房流理台下方柜子',
  feedingAmount: '1.5',
  waterRequirement: '需清洗饮水机并换新水...',
  needPlayTime: true,
  videoCheckpoints: defaultVideoCheckpoints,
  baseFee: 30.00,
  playTimeFee: 5.00,
  holidayFee: 0.00
}
