'use client'

import { Key, Utensils, Droplets, Gamepad2, Plus, DoorOpen, UtensilsCrossed, FileText } from 'lucide-react'
import { Switch } from '@/components/ui/switch'
import type { VideoCheckpoint } from '@/types/order'

interface StepServiceRequirementsProps {
  keyLocation: string
  onKeyLocationChange: (value: string) => void
  smartLockPassword: string
  onSmartLockPasswordChange: (value: string) => void
  foodLocation: string
  onFoodLocationChange: (value: string) => void
  feedingAmount: string
  onFeedingAmountChange: (value: string) => void
  waterRequirement: string
  onWaterRequirementChange: (value: string) => void
  needPlayTime: boolean
  onPlayTimeToggle: (value: boolean) => void
  videoCheckpoints: VideoCheckpoint[]
}

export function StepServiceRequirements({
  keyLocation,
  onKeyLocationChange,
  smartLockPassword,
  onSmartLockPasswordChange,
  foodLocation,
  onFoodLocationChange,
  feedingAmount,
  onFeedingAmountChange,
  waterRequirement,
  onWaterRequirementChange,
  needPlayTime,
  onPlayTimeToggle,
  videoCheckpoints
}: StepServiceRequirementsProps) {
  const getCheckpointIcon = (icon: string) => {
    switch (icon) {
      case 'door':
        return <DoorOpen className="w-4 h-4" />
      case 'food':
        return <UtensilsCrossed className="w-4 h-4" />
      case 'clean':
        return <FileText className="w-4 h-4" />
      default:
        return <FileText className="w-4 h-4" />
    }
  }

  return (
    <div className="flex-1 overflow-y-auto px-5 pb-4">
      {/* 入户指引 */}
      <section className="mb-6 p-5 rounded-2xl bg-card border border-border">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center">
            <Key className="w-4 h-4 text-primary" />
          </div>
          <h3 className="text-base font-medium text-foreground">入户指引</h3>
        </div>
        
        <div className="space-y-4">
          <div>
            <label className="text-xs text-muted-foreground mb-2 block">钥匙存放位置</label>
            <input
              type="text"
              value={keyLocation}
              onChange={(e) => onKeyLocationChange(e.target.value)}
              placeholder="例如：门口地垫下、消防栓箱内..."
              className="w-full px-4 py-3 rounded-xl bg-secondary text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>
          
          <div>
            <label className="text-xs text-muted-foreground mb-2 block">智能锁密码</label>
            <input
              type="text"
              value={smartLockPassword}
              onChange={(e) => onSmartLockPasswordChange(e.target.value)}
              placeholder="输入密码或备注临时授权方式"
              className="w-full px-4 py-3 rounded-xl bg-secondary text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>
        </div>
      </section>

      {/* 喂食要求 */}
      <section className="mb-6 p-5 rounded-2xl bg-card border border-border">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center">
            <Utensils className="w-4 h-4 text-primary" />
          </div>
          <h3 className="text-base font-medium text-foreground">喂食要求</h3>
        </div>
        
        <div className="space-y-4">
          <div>
            <label className="text-xs text-primary mb-2 block">猫粮位置</label>
            <input
              type="text"
              value={foodLocation}
              onChange={(e) => onFoodLocationChange(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-secondary text-sm font-medium text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>
          
          <div>
            <label className="text-xs text-muted-foreground mb-2 block">喂食份量</label>
            <div className="flex items-baseline gap-2">
              <input
                type="text"
                value={feedingAmount}
                onChange={(e) => onFeedingAmountChange(e.target.value)}
                className="w-16 px-4 py-3 rounded-xl bg-secondary text-lg font-semibold text-foreground focus:outline-none focus:ring-2 focus:ring-primary/20"
              />
              <span className="text-sm text-muted-foreground">勺/次</span>
            </div>
          </div>
        </div>
      </section>

      {/* 饮水要求 */}
      <section className="mb-6 p-5 rounded-2xl bg-card border border-border">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center">
            <Droplets className="w-4 h-4 text-primary" />
          </div>
          <h3 className="text-base font-medium text-foreground">饮水要求</h3>
        </div>
        
        <textarea
          value={waterRequirement}
          onChange={(e) => onWaterRequirementChange(e.target.value)}
          placeholder="需清洗饮水机并换新水..."
          rows={3}
          className="w-full px-4 py-3 rounded-xl bg-secondary text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none"
        />
      </section>

      {/* 需要陪玩 */}
      <section className="mb-6 p-4 rounded-2xl bg-secondary">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center">
              <Gamepad2 className="w-4 h-4 text-primary" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">需要陪玩</p>
              <p className="text-xs text-muted-foreground">服务者将额外陪伴猫咪15分钟</p>
            </div>
          </div>
          <Switch checked={needPlayTime} onCheckedChange={onPlayTimeToggle} />
        </div>
      </section>

      {/* 拍照/视频节点提示 */}
      <section className="mb-6">
        <p className="text-sm text-muted-foreground mb-3">拍照/视频节点提示</p>
        <div className="grid grid-cols-2 gap-3">
          {videoCheckpoints.map((checkpoint) => (
            <div
              key={checkpoint.id}
              className="flex items-center gap-2 px-4 py-3 rounded-xl bg-card border border-border"
            >
              <span className="text-muted-foreground">{getCheckpointIcon(checkpoint.icon)}</span>
              <span className="text-sm text-foreground">{checkpoint.label}</span>
            </div>
          ))}
          <button className="flex items-center gap-2 px-4 py-3 rounded-xl border border-dashed border-border text-muted-foreground hover:border-primary hover:text-primary transition-colors">
            <Plus className="w-4 h-4" />
            <span className="text-sm">添加节点</span>
          </button>
        </div>
      </section>

      {/* 底部提示卡片 */}
      <section className="mb-6 rounded-2xl overflow-hidden relative">
        <img
          src="https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=400&h=200&fit=crop"
          alt="专业猫咪呵护"
          className="w-full h-40 object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
        <div className="absolute bottom-4 left-4 right-4">
          <p className="text-xs text-primary-foreground/80 tracking-wider mb-1">SAFETY FIRST</p>
          <p className="text-sm font-medium text-primary-foreground">专业的猫咪呵护，从细节开始</p>
        </div>
      </section>
    </div>
  )
}
