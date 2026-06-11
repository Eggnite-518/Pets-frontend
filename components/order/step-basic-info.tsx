'use client'

import { Plus, Check, Calendar, Clock, MapPin, ChevronRight, Pencil } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Pet, ServiceType, Address } from '@/types/order'

interface StepBasicInfoProps {
  pets: Pet[]
  selectedPets: string[]
  onPetSelect: (petId: string) => void
  serviceTypes: ServiceType[]
  selectedService: string
  onServiceSelect: (serviceId: string) => void
  serviceDate: string
  serviceTime: string
  address: Address | null
}

export function StepBasicInfo({
  pets,
  selectedPets,
  onPetSelect,
  serviceTypes,
  selectedService,
  onServiceSelect,
  serviceDate,
  serviceTime,
  address
}: StepBasicInfoProps) {
  return (
    <div className="flex-1 overflow-y-auto px-5 pb-4">
      {/* 选择宠物 */}
      <section className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-medium text-foreground">选择宠物</h3>
          <span className="text-sm text-primary">
            已选择 {selectedPets.length}
          </span>
        </div>
        <div className="flex gap-4 overflow-x-auto pb-2">
          {/* 添加宠物按钮 */}
          <button className="flex-shrink-0 flex flex-col items-center gap-2">
            <div className="w-20 h-20 rounded-full border-2 border-dashed border-border flex items-center justify-center text-muted-foreground hover:border-primary hover:text-primary transition-colors">
              <Plus className="w-6 h-6" />
            </div>
            <span className="text-xs text-muted-foreground">添加宠物</span>
          </button>
          
          {/* 宠物列表 */}
          {pets.map((pet) => {
            const isSelected = selectedPets.includes(pet.id)
            return (
              <button
                key={pet.id}
                onClick={() => onPetSelect(pet.id)}
                className="flex-shrink-0 flex flex-col items-center gap-2"
              >
                <div className="relative">
                  <div
                    className={cn(
                      'w-20 h-20 rounded-full overflow-hidden border-2 transition-all',
                      isSelected ? 'border-primary' : 'border-transparent'
                    )}
                  >
                    <img
                      src={pet.avatar}
                      alt={pet.name}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  {isSelected && (
                    <div className="absolute -top-1 -right-1 w-6 h-6 bg-primary rounded-full flex items-center justify-center">
                      <Check className="w-4 h-4 text-primary-foreground" />
                    </div>
                  )}
                </div>
                <span className={cn(
                  'text-sm',
                  isSelected ? 'text-foreground font-medium' : 'text-muted-foreground'
                )}>
                  {pet.name}
                </span>
              </button>
            )
          })}
        </div>
      </section>

      {/* 服务类型 */}
      <section className="mb-8">
        <h3 className="text-base font-medium text-foreground mb-4">服务类型</h3>
        <div className="grid grid-cols-2 gap-3">
          {serviceTypes.map((service) => {
            const isSelected = selectedService === service.id
            return (
              <button
                key={service.id}
                onClick={() => onServiceSelect(service.id)}
                className={cn(
                  'flex flex-col items-center gap-2 py-5 px-4 rounded-2xl border-2 transition-all',
                  isSelected
                    ? 'border-primary bg-secondary'
                    : 'border-border bg-card hover:border-primary/50'
                )}
              >
                <div className={cn(
                  'w-10 h-10 rounded-full flex items-center justify-center',
                  isSelected ? 'text-primary' : 'text-muted-foreground'
                )}>
                  {service.icon === 'cat' ? (
                    <svg className="w-7 h-7" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 15h2v-2h-2v2zm0-4h2V7h-2v6z" opacity="0" />
                      <path d="M4.5 12c0 .28.22.5.5.5h2c.28 0 .5-.22.5-.5s-.22-.5-.5-.5H5c-.28 0-.5.22-.5.5zm12.5-.5h2c.28 0 .5.22.5.5s-.22.5-.5.5h-2c-.28 0-.5-.22-.5-.5s.22-.5.5-.5zM12 4.5c.28 0 .5.22.5.5v2c0 .28-.22.5-.5.5s-.5-.22-.5-.5V5c0-.28.22-.5.5-.5zm0 12c.28 0 .5.22.5.5v2c0 .28-.22.5-.5.5s-.5-.22-.5-.5v-2c0-.28.22-.5.5-.5z" opacity="0" />
                      <path d="M12 5c-1.93 0-3.68.78-4.95 2.05l-1.41-1.41C7.28 4 9.52 3 12 3s4.72 1 6.36 2.64l-1.41 1.41C15.68 5.78 13.93 5 12 5z" opacity="0" />
                      <circle cx="9" cy="12" r="1.5" />
                      <circle cx="15" cy="12" r="1.5" />
                      <path d="M8 16s1.5 2 4 2 4-2 4-2" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                      <path d="M3 7l2 3M21 7l-2 3M3 5l3 4M21 5l-3 4" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                    </svg>
                  ) : (
                    <svg className="w-7 h-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                      <circle cx="12" cy="5" r="2" />
                      <path d="M12 7v4M8 22v-7l-3-3 2-4M16 22v-7l3-3-2-4M9 11h6" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  )}
                </div>
                <div className="text-center">
                  <p className={cn(
                    'text-sm font-medium',
                    isSelected ? 'text-primary' : 'text-foreground'
                  )}>
                    {service.name}
                  </p>
                  <p className="text-xs text-muted-foreground">{service.nameEn}</p>
                </div>
              </button>
            )
          })}
        </div>
      </section>

      {/* 服务时间 */}
      <section className="mb-8">
        <h3 className="text-base font-medium text-foreground mb-4">服务时间</h3>
        
        {/* 服务日期 */}
        <button className="w-full flex items-center gap-4 py-4 border-b border-border">
          <Calendar className="w-5 h-5 text-muted-foreground" />
          <div className="flex-1 text-left">
            <p className="text-xs text-muted-foreground mb-0.5">服务日期</p>
            <p className="text-sm font-medium text-foreground">{serviceDate}</p>
          </div>
          <ChevronRight className="w-5 h-5 text-muted-foreground" />
        </button>
        
        {/* 首选时段 */}
        <div className="mt-4 p-4 rounded-2xl border-2 border-accent/30 bg-accent/5">
          <div className="flex items-center gap-4">
            <Clock className="w-5 h-5 text-muted-foreground" />
            <div className="flex-1">
              <p className="text-xs text-muted-foreground mb-0.5">首选时段</p>
              <p className="text-sm font-medium text-foreground">{serviceTime}</p>
            </div>
            <button className="p-2 text-muted-foreground hover:text-primary transition-colors">
              <Pencil className="w-4 h-4" />
            </button>
          </div>
        </div>
      </section>

      {/* 服务地址 */}
      <section className="mb-8">
        <h3 className="text-base font-medium text-foreground mb-4">服务地址</h3>
        {address && (
          <div className="p-4 rounded-2xl bg-card border border-border">
            <div className="flex items-start gap-3">
              <MapPin className="w-5 h-5 text-primary mt-0.5 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-sm font-medium text-foreground">{address.district}</span>
                  {address.isDefault && (
                    <span className="px-2 py-0.5 text-xs bg-primary text-primary-foreground rounded">
                      默认
                    </span>
                  )}
                </div>
                <p className="text-sm text-muted-foreground mb-1">{address.detail}</p>
                <p className="text-sm text-muted-foreground">
                  {address.contact} {address.phone}
                </p>
              </div>
              <button className="p-2 text-muted-foreground hover:text-primary transition-colors flex-shrink-0">
                <Pencil className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </section>
    </div>
  )
}
