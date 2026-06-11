'use client'

import { Calendar, MapPin, Minus, Plus, Shield, Wallet, Info, Lock } from 'lucide-react'
import type { Pet, Address } from '@/types/order'

interface StepCostConfirmationProps {
  serviceType: string
  serviceDate: string
  serviceTime: string
  address: Address | null
  selectedPet: Pet | null
  baseFee: number
  onBaseFeeChange: (value: number) => void
  playTimeFee: number
  onPlayTimeFeeChange: (value: number) => void
  holidayFee: number
  onHolidayFeeChange: (value: number) => void
}

export function StepCostConfirmation({
  serviceType,
  serviceDate,
  serviceTime,
  address,
  selectedPet,
  baseFee,
  onBaseFeeChange,
  playTimeFee,
  onPlayTimeFeeChange,
  holidayFee,
  onHolidayFeeChange
}: StepCostConfirmationProps) {
  const totalFee = baseFee + playTimeFee + holidayFee

  const FeeRow = ({
    label,
    value,
    onChange
  }: {
    label: string
    value: number
    onChange: (value: number) => void
  }) => (
    <div className="flex items-center justify-between py-3">
      <span className="text-sm text-foreground">{label}</span>
      <div className="flex items-center gap-3">
        <button
          onClick={() => onChange(Math.max(0, value - 5))}
          className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-muted-foreground hover:bg-primary/10 hover:text-primary transition-colors"
        >
          <Minus className="w-4 h-4" />
        </button>
        <span className="w-16 text-right font-medium text-foreground">
          ¥{value.toFixed(2)}
        </span>
        <button
          onClick={() => onChange(value + 5)}
          className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-muted-foreground hover:bg-primary/10 hover:text-primary transition-colors"
        >
          <Plus className="w-4 h-4" />
        </button>
      </div>
    </div>
  )

  return (
    <div className="flex-1 overflow-y-auto px-5 pb-4">
      {/* 订单摘要卡片 */}
      <section className="mb-6 p-5 rounded-2xl bg-card border border-border">
        <div className="flex items-start justify-between mb-4">
          <span className="inline-block px-3 py-1 text-xs font-medium bg-primary text-primary-foreground rounded-lg">
            上门喂养 · 上门猫/狗
          </span>
          {selectedPet && (
            <div className="flex flex-col items-center">
              <div className="w-14 h-14 rounded-full overflow-hidden border-2 border-border">
                <img
                  src={selectedPet.avatar}
                  alt={selectedPet.name}
                  className="w-full h-full object-cover"
                />
              </div>
              <span className="text-xs text-muted-foreground mt-1">{selectedPet.name}</span>
            </div>
          )}
        </div>

        <div className="space-y-3">
          <div className="flex items-start gap-3">
            <Calendar className="w-4 h-4 text-muted-foreground mt-0.5 flex-shrink-0" />
            <div>
              <p className="text-xs text-muted-foreground">预约时间</p>
              <p className="text-sm font-medium text-foreground">
                {serviceDate}
              </p>
              <p className="text-sm font-medium text-foreground">{serviceTime.split(' - ')[0]}</p>
            </div>
          </div>

          {address && (
            <div className="flex items-start gap-3">
              <MapPin className="w-4 h-4 text-primary mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-xs text-muted-foreground">服务地址</p>
                <p className="text-sm font-medium text-foreground">
                  {address.district}{address.detail}
                </p>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* 费用清单 */}
      <section className="mb-6">
        <h3 className="text-base font-medium text-foreground mb-4">费用清单</h3>
        <div className="p-5 rounded-2xl bg-card border border-border">
          <FeeRow label="基础服务费" value={baseFee} onChange={onBaseFeeChange} />
          <FeeRow label="陪玩15min" value={playTimeFee} onChange={onPlayTimeFeeChange} />
          <FeeRow label="节假日/夜间附加费" value={holidayFee} onChange={onHolidayFeeChange} />
          
          <div className="border-t border-dashed border-border mt-4 pt-4">
            <div className="flex items-baseline justify-between">
              <span className="text-base font-medium text-foreground">合计金额</span>
              <div className="flex items-baseline gap-1">
                <span className="text-sm text-muted-foreground">RMB</span>
                <span className="text-3xl font-bold text-primary">{totalFee.toFixed(2)}</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 保障卡片 */}
      <section className="mb-6 grid grid-cols-2 gap-3">
        <div className="p-4 rounded-2xl bg-card border border-border flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
            <Shield className="w-5 h-5 text-primary" />
          </div>
          <div>
            <p className="text-sm font-medium text-foreground">平安保险</p>
            <p className="text-xs text-muted-foreground">全程意外承保</p>
          </div>
        </div>
        <div className="p-4 rounded-2xl bg-card border border-border flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
            <Wallet className="w-5 h-5 text-primary" />
          </div>
          <div>
            <p className="text-sm font-medium text-foreground">资金托管</p>
            <p className="text-xs text-muted-foreground">确认收货后结算</p>
          </div>
        </div>
      </section>

      {/* 温馨提示 */}
      <section className="mb-6 p-4 rounded-xl bg-accent/10 border border-accent/20">
        <div className="flex gap-3">
          <Info className="w-4 h-4 text-accent flex-shrink-0 mt-0.5" />
          <p className="text-xs text-foreground leading-relaxed">
            温馨提示：为了您的财产安全，请勿脱离平台进行私下交易。平台将为您提供全程服务监管与保障。
          </p>
        </div>
      </section>

      {/* 支付状态 */}
      <section className="mb-6 flex items-center justify-between text-sm">
        <div className="flex items-center gap-2 text-muted-foreground">
          <span className="w-2 h-2 rounded-full bg-primary animate-pulse" />
          <span>正在连接安全支付网关...</span>
        </div>
        <div className="flex items-center gap-1 text-muted-foreground">
          <Lock className="w-4 h-4" />
          <span className="text-xs font-medium tracking-wide">SECURE PAYMENT</span>
        </div>
      </section>
    </div>
  )
}
