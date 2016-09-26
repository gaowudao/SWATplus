      subroutine time_control

!!    ~ ~ ~ PURPOSE ~ ~ ~
!!    this subroutine contains the loops governing the modeling of processes
!!    in the watershed 

!!    ~ ~ ~ INCOMING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    biomix(:)   |none          |biological mixing efficiency.
!!                               |Mixing of soil due to activity of earthworms
!!                               |and other soil biota. Mixing is performed at
!!                               |the end of every calendar year.
!!    hi_targ(:,:,:)|(kg/ha)/(kg/ha)|harvest index target of cover defined at
!!                               |planting
!!    icr(:)      |none          |sequence number of crop grown within the
!!                               |current year
!!    mcr         |none          |max number of crops grown per year
!!    nhru        |none          |number of HRUs in watershed
!!    tnyld(:)    |kg N/kg yield |modifier for autofertilization target
!!                               |nitrogen content for plant
!!    tnylda(:)   |kg N/kg yield |estimated/target nitrogen content of
!!                               |yield used in autofertilization
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ OUTGOING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    curyr       |none          |current year in simulation (sequence)
!!    hi_targ(:,:,:)|(kg/ha)/(kg/ha)|harvest index target of cover defined at
!!                               |planting
!!    i           |julian date   |current day in simulation--loop counter
!!    icr(:)      |none          |sequence number of crop grown within the
!!                               |current year
!!    iida        |julian date   |day being simulated (current julian day)

!!    ntil(:)     |none          |sequence number of tillage operation within
!!                               |current year
!!    tnylda(:)   |kg N/kg yield |estimated/target nitrogen content of
!!                               |yield used in autofertilization
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ LOCAL DEFINITIONS ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    ic          |none          |counter
!!    iix         |none          |sequence number of current year in rotation
!!    iiz         |none          |sequence number of current crop grown
!!                               |within the current year
!!    j           |none          |counter
!!    xx          |none          |current year in simulation sequence
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ SUBROUTINES/FUNCTIONS CALLED ~ ~ ~
!!    Intrinsic: Mod, Real
!!    SWAT: sim_inityr, std3, xmon, sim_initday, clicon, command
!!    SWAT: writed, writem, tillmix

!!    ~ ~ ~ ~ ~ ~ END SPECIFICATIONS ~ ~ ~ ~ ~ ~

      use jrw_datalib_module
      use parm
      use time_module
      use mgtops_module
      use climate_module
      use basin_module
      use sd_channel_module
      use sd_hru_module
      
      integer :: j, iix, iiz, ic, mon, ii
      integer :: isce = 1
      real :: xx
      character(len=16):: chg_parm, chg_typ

      time%yrc = time%yrc_start

      do curyr = 1, time%nbyr
        time%yrs = curyr
        
        !! initialize annual variables for hru's
        if (sp_ob%hru > 0) call sim_inityr

        !!determine beginning and ending dates of simulation in current year
        if (Mod(time%yrc,4) == 0) then 
          ndays = ndays_leap
        else 
          ndays = ndays_noleap
        end if

        !! set beginning day of simulation for year
        if (time%yrs > 1 .or. time%idaf == 0) then
          time%idaf = 1
        end if

        !! set ending day of simulation for year
        time%idal = ndays(13)
        if (time%yrs == time%nbyr .and. time%idal_in > 0) then
          time%idal = time%idal_in
        end if
        
        !! sum years of printing for average annual writes
        if (time%yrs > pco%nyskip) then
          time%yrs_prt = time%yrs_prt + float(time%idal - time%idaf + 1)
        else
          !! tell user they are skipping more years than simulating
          time%yrs_prt = time%nbyr
        end if
        
        !! set current julian date to begin annual simulation
        iida = time%idaf

        call xmon
       if (ifirstatmo == 1) then
         ifirstatmo = 0
         if (bsn_cc%atmo == 2) then 
           iyr_at = iyr_atmo1
           mo_at = mo_atmo1
            do
              mo_atmo = mo_atmo + 1
              if (iyr_at == time%yrc .and. mo_at == i_mo) exit
              mo_at = mo_at + 1
              if (mo_at > 12) then
                mo_at = 1
                iyr_at = iyr_at + 1
              endif
              if (mo_atmo > 1000) exit
            end do  
         endif
       endif
       
        do i = time%idaf, time%idal       !! begin daily loop
            
          !! determine month
          iida = i
          call xmon
          time%day = i
          write (*,1234) time%yrs, time%day
          time%mo = i_mo
          !! check for end of month, year and simulation
          time%end_mo = 0
          time%end_yr = 0
          time%end_sim = 0
          if (i == ndays(i_mo+1)) then
            time%end_mo = 1
          end if
          if (i == time%idal) then
            time%end_yr = 1
            if (time%yrs == time%nbyr) then
              time%end_sim = 1
              time%yrs_prt = time%yrs_prt / 365.
            end if
          end if
          
          !! check time interval for daily printing
          if (time%yrc >= pco%yr_start .and. time%day >= pco%jd_start .and. time%yrc <= pco%yr_end   &
                                             .and. time%day <= pco%jd_end) then
            int_print = int_print + 1
            if (int_print > pco%interval) int_print = 1
          end if

          !! initialize variables at beginning of day for hru's
          if (sp_ob%hru > 0) call sim_initday

          dtot = dtot + 1.

          if (time%yrs > pco%nyskip) ndmo(i_mo) = ndmo(i_mo) + 1

          call climate_control      !! read in/generate weather
          
          !! check to determine if scenarios need to be set
          if (db_mx%sched_up > 0) then
          do while (time%day == upd_sched(isce)%day .and. time%yrc == upd_sched(isce)%year)
            if (upd_sched(isce)%typ == 'structure') then
                do ispu = 1, upd_sched(isce)%num_tot
                  ielem = upd_sched(isce)%num(ispu)
                  call structure_set_parms (upd_sched(isce)%name, upd_sched(isce)%str_lu, ielem)
                end do
            else if (upd_sched(isce)%typ == 'land_use') then
              !! change management or entire land use
            end if
          isce = isce + 1
          if (isce > db_mx%sched_up) isce = 1
          end do
          end if

          !! conditional reset of land use and management
          if (time%day == 1) then  !only on first day of year
            do iupd = 1, db_mx%cond_up
              if (upd_cond(iupd)%typ == 'land_use') then
                do j = 1, sp_ob%hru
                  id = upd_cond(iupd)%cond_num
                  call conditions (id, j)
                  call actions (id, j)
                end do
              end if
            end do
          end if
          
          !! conditional reset of channel management
          if (time%day == 1) then  !only on first day of year
            do iupd = 1, db_mx%cond_up
              if (upd_cond(iupd)%typ == 'chan_use') then
                do j = 1, sp_ob%chandeg
                  id = upd_cond(iupd)%cond_num
                  call conditions (id, j)
                  call actions (id, j)
                end do
              end if
            end do
          end if
          
          !! allocate water for water rights objects
          !call water_allocation

          call command              !! command loop
          
          call soil_write  

        do ihru = 1, nhru  
          isched = hru(j)%mgt_ops
          if (sched(isched)%num_ops > 0) then
          if (time%idaf > 180 .and. wst(iwst)%lat < 0) then
            if (i == 180) then
              isched = hru(j)%mgt_ops
              if (sched(isched)%mgt_ops(nop(ihru))%op /= "skip") then
                dorm_flag = 1
                call mgt_operatn
                dorm_flag = 0
              endif
              nop(ihru) = nop(ihru) + 1
              if (nop(ihru) > sched(isched)%num_ops) then
                nop(ihru) = 1
              end if
      
              phubase(ihru) = 0.
	        yr_skip(ihru) = 0
	      endif
	    end if
	    endif
        end do

        end do                                        !! end daily loop

        !! perform end-of-year processes
        
        !! sum landscape output for soft data calibration
        if (cal_codes%hyd_hru == 'y') then
          !calibrate hru's
          do ireg = 1, db_mx%lscal_reg
            do ilu = 1, lscal(ireg)%lum_num
              lscal(ireg)%lum(ilu)%ha = 0.
              lscal(ireg)%lum(ilu)%precip = 0.
              lscal(ireg)%lum(ilu)%sim = lscal_z  !! zero all calibration parameters
              do ihru_s = 1, lscal(ireg)%num_tot
                ihru = lscal(ireg)%num(ihru_s)
                if (lscal(ireg)%lum(ilu)%meas%name == hru(ihru)%land_use_mgt_c) then
                  ha_hru = 100. * hru(ihru)%km      ! 10 * ha * mm --> m3
                  lscal(ireg)%lum(ilu)%ha = lscal(ireg)%lum(ilu)%ha + ha_hru
                  lscal(ireg)%lum(ilu)%precip = lscal(ireg)%lum(ilu)%precip + (10. * ha_hru * hwb_y(ihru)%precip)
                  lscal(ireg)%lum(ilu)%sim%srr = lscal(ireg)%lum(ilu)%sim%srr + (10. * ha_hru * hwb_y(ihru)%surq_gen)
                  lscal(ireg)%lum(ilu)%sim%lfr = lscal(ireg)%lum(ilu)%sim%lfr + (10. * ha_hru * hwb_y(ihru)%latq)
                  lscal(ireg)%lum(ilu)%sim%pcr = lscal(ireg)%lum(ilu)%sim%pcr + (10. * ha_hru * hwb_y(ihru)%perc)
                  lscal(ireg)%lum(ilu)%sim%etr = lscal(ireg)%lum(ilu)%sim%etr + (10. * ha_hru * hwb_y(ihru)%et)
                  lscal(ireg)%lum(ilu)%sim%tfr = lscal(ireg)%lum(ilu)%sim%tfr + (10. * ha_hru * hwb_y(ihru)%qtile)
                  lscal(ireg)%lum(ilu)%sim%sed = lscal(ireg)%lum(ilu)%sim%sed + (ha_hru * hls_y(ihru)%sedyld)
                  !add nutrients
                end if
              end do
            end do  !lum_num
            
            do ilu = 1, lscal(ireg)%lum_num
              if (lscal(ireg)%lum(ilu)%ha > 1.e-6) then
                lscal(ireg)%lum(ilu)%nbyr = lscal(ireg)%lum(ilu)%nbyr + 1
                !! convert back to mm, t/ha, kg/ha
                lscal(ireg)%lum(ilu)%precip_aa = lscal(ireg)%lum(ilu)%precip_aa + lscal(ireg)%lum(ilu)%precip / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%srr = lscal(ireg)%lum(ilu)%aa%srr + lscal(ireg)%lum(ilu)%sim%srr / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%lfr = lscal(ireg)%lum(ilu)%aa%lfr + lscal(ireg)%lum(ilu)%sim%lfr / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%pcr = lscal(ireg)%lum(ilu)%aa%pcr + lscal(ireg)%lum(ilu)%sim%pcr / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%etr = lscal(ireg)%lum(ilu)%aa%etr + lscal(ireg)%lum(ilu)%sim%etr / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%tfr = lscal(ireg)%lum(ilu)%aa%tfr + lscal(ireg)%lum(ilu)%sim%tfr / (10. * lscal(ireg)%lum(ilu)%ha)
                lscal(ireg)%lum(ilu)%aa%sed = lscal(ireg)%lum(ilu)%aa%sed + lscal(ireg)%lum(ilu)%sim%sed / lscal(ireg)%lum(ilu)%ha
                ! add nutrients
              end if
            end do
          end do    !reg
        end if
        
        if (cal_codes%hyd_hrul == 'y') then
          !calibrate hru_lte's
          do ireg = 1, db_mx%lscalt_reg
            do ilu = 1, lscalt(ireg)%lum_num
              lscalt(ireg)%lum(ilu)%ha = 0.
              lscalt(ireg)%lum(ilu)%precip = 0.
              lscalt(ireg)%lum(ilu)%sim = lscal_z  !! zero all calibration parameters
              do ihru_s = 1, lscalt(ireg)%num_tot
                ihru = lscalt(ireg)%num(ihru_s)
                !if (lscal(ireg)%lum(ilu)%lum_no == hru(ihru)%land_use_mgt) then
                  ha_hru = 100. * sd(ihru)%km2      ! 10 * ha * mm --> m3
                  lscalt(ireg)%lum(ilu)%ha = lscalt(ireg)%lum(ilu)%ha + ha_hru
                  lscalt(ireg)%lum(ilu)%precip = lscalt(ireg)%lum(ilu)%precip + (10. * ha_hru * sdwb_y(ihru)%precip)
                  lscalt(ireg)%lum(ilu)%sim%srr = lscalt(ireg)%lum(ilu)%sim%srr + (10. * ha_hru * sdwb_y(ihru)%surq_gen)
                  lscalt(ireg)%lum(ilu)%sim%lfr = lscalt(ireg)%lum(ilu)%sim%lfr + (10. * ha_hru * sdwb_y(ihru)%latq)
                  lscalt(ireg)%lum(ilu)%sim%pcr = lscalt(ireg)%lum(ilu)%sim%pcr + (10. * ha_hru * sdwb_y(ihru)%perc)
                  lscalt(ireg)%lum(ilu)%sim%etr = lscalt(ireg)%lum(ilu)%sim%etr + (10. * ha_hru * sdwb_y(ihru)%et)
                  lscalt(ireg)%lum(ilu)%sim%tfr = lscalt(ireg)%lum(ilu)%sim%tfr + (10. * ha_hru * sdwb_y(ihru)%qtile)
                  lscalt(ireg)%lum(ilu)%sim%sed = lscalt(ireg)%lum(ilu)%sim%sed + (ha_hru * sdls_y(ihru)%sedyld)
                  !add nutrients
                !end if
              end do
            end do  !lum_num
            
            do ilu = 1, lscalt(ireg)%lum_num
              if (lscalt(ireg)%lum(ilu)%ha > 1.e-6) then
                lscalt(ireg)%lum(ilu)%nbyr = lscalt(ireg)%lum(ilu)%nbyr + 1
                !! convert back to mm, t/ha, kg/ha
                lscalt(ireg)%lum(ilu)%precip_aa = lscalt(ireg)%lum(ilu)%precip_aa + lscalt(ireg)%lum(ilu)%precip / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%srr = lscalt(ireg)%lum(ilu)%aa%srr + lscalt(ireg)%lum(ilu)%sim%srr / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%lfr = lscalt(ireg)%lum(ilu)%aa%lfr + lscalt(ireg)%lum(ilu)%sim%lfr / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%pcr = lscalt(ireg)%lum(ilu)%aa%pcr + lscalt(ireg)%lum(ilu)%sim%pcr / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%etr = lscalt(ireg)%lum(ilu)%aa%etr + lscalt(ireg)%lum(ilu)%sim%etr / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%tfr = lscalt(ireg)%lum(ilu)%aa%tfr + lscalt(ireg)%lum(ilu)%sim%tfr / (10. * lscalt(ireg)%lum(ilu)%ha)
                lscalt(ireg)%lum(ilu)%aa%sed = lscalt(ireg)%lum(ilu)%aa%sed + lscalt(ireg)%lum(ilu)%sim%sed / lscalt(ireg)%lum(ilu)%ha
                ! add nutrients
              end if
            end do
          end do    !reg
        end if
          
        !! sum landscape output for plant soft data calibration
        if (cal_codes%plt == 'y') then
          !calibrate plnt growth
          do ireg = 1, db_mx%plcal_reg
            do ilu = 1, plcal(ireg)%lum_num
              plcal(ireg)%lum(ilu)%ha = 0.
              plcal(ireg)%lum(ilu)%precip = 0.
              plcal(ireg)%lum(ilu)%sim = plcal_z  !! zero all calibration parameters
              do ihru_s = 1, plcal(ireg)%num_tot
                ihru = plcal(ireg)%num(ihru_s)
                if (plcal(ireg)%lum(ilu)%meas%name == sd(ihru)%plant) then
                  ha_hru = 100. * sd(ihru)%km2      ! 10 * ha * mm --> m3
                  plcal(ireg)%lum(ilu)%ha = plcal(ireg)%lum(ilu)%ha + ha_hru
                  plcal(ireg)%lum(ilu)%precip = plcal(ireg)%lum(ilu)%precip + (10. * ha_hru * sdwb_y(ihru)%precip)
                  plcal(ireg)%lum(ilu)%sim%yield = plcal(ireg)%lum(ilu)%sim%yield + (10. * ha_hru * sd(ihru)%yield)
                  plcal(ireg)%lum(ilu)%sim%npp = plcal(ireg)%lum(ilu)%sim%npp + (10. * ha_hru * sd(ihru)%npp)
                  plcal(ireg)%lum(ilu)%sim%lai_mx = plcal(ireg)%lum(ilu)%sim%lai_mx + (10. * ha_hru * sd(ihru)%lai_mx)
                  plcal(ireg)%lum(ilu)%sim%wstress = plcal(ireg)%lum(ilu)%sim%wstress + (10. * ha_hru * sdpw_y(ihru)%strsw)
                  plcal(ireg)%lum(ilu)%sim%astress = plcal(ireg)%lum(ilu)%sim%astress + (10. * ha_hru * sdpw_y(ihru)%strsa)
                  plcal(ireg)%lum(ilu)%sim%tstress = plcal(ireg)%lum(ilu)%sim%tstress + (ha_hru * sdpw_y(ihru)%strstmp)
                end if
              end do
            end do  !lum_num
            
            do ilu = 1, plcal(ireg)%lum_num
              if (plcal(ireg)%lum(ilu)%ha > 1.e-6) then
                plcal(ireg)%lum(ilu)%nbyr = plcal(ireg)%lum(ilu)%nbyr + 1
                !! convert back to mm, t/ha, kg/ha
                plcal(ireg)%lum(ilu)%precip_aa = plcal(ireg)%lum(ilu)%precip_aa + plcal(ireg)%lum(ilu)%precip / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%yield = plcal(ireg)%lum(ilu)%aa%yield + plcal(ireg)%lum(ilu)%sim%yield / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%npp = plcal(ireg)%lum(ilu)%aa%npp + plcal(ireg)%lum(ilu)%sim%npp / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%lai_mx = plcal(ireg)%lum(ilu)%aa%lai_mx + plcal(ireg)%lum(ilu)%sim%lai_mx / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%wstress = plcal(ireg)%lum(ilu)%aa%wstress + plcal(ireg)%lum(ilu)%sim%wstress / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%astress = plcal(ireg)%lum(ilu)%aa%astress + plcal(ireg)%lum(ilu)%sim%astress / (10. * plcal(ireg)%lum(ilu)%ha)
                plcal(ireg)%lum(ilu)%aa%tstress = plcal(ireg)%lum(ilu)%aa%tstress + plcal(ireg)%lum(ilu)%sim%tstress / plcal(ireg)%lum(ilu)%ha
                ! add nutrients
              end if
            end do
          end do    !reg
        end if

        !! sum channel output for soft data calibration
        if (cal_codes%chsed == 'y' .and. cal_codes%sed == 'n' .and. cal_codes%plt == 'n' .and. cal_codes%hyd_hru == 'n' .and. cal_codes%hyd_hrul == 'n') then
          do ireg = 1, db_mx%chcal_reg
            do iord = 1, chcal(ireg)%ord_num
              chcal(ireg)%ord(iord)%length = 0.
              chcal(ireg)%ord(iord)%sim = chcal_z  !! zero all calibration parameters
              do ich_s = 1, chcal(ireg)%num_tot
                ich = chcal(ireg)%num(ich_s)
                if (chcal(ireg)%ord(iord)%meas%name == sd_ch(ich)%order) then
                  chcal(ireg)%ord(iord)%nbyr = chcal(ireg)%ord(iord)%nbyr + 1
                  chcal(ireg)%ord(iord)%length = chcal(ireg)%ord(iord)%length + sd_ch(ich)%chl
                  chcal(ireg)%ord(iord)%aa%chw = chcal(ireg)%ord(iord)%aa%chw + chsd_y(ich)%deg_bank_m * sd_ch(ich)%chl
                  chcal(ireg)%ord(iord)%aa%chd = chcal(ireg)%ord(iord)%aa%chd + chsd_y(ich)%deg_btm_m * sd_ch(ich)%chl
                  chcal(ireg)%ord(iord)%aa%hc = chcal(ireg)%ord(iord)%aa%hc + chsd_y(ich)%hc_m * sd_ch(ich)%chl
                  chcal(ireg)%ord(iord)%aa%fpd = chcal(ireg)%ord(iord)%aa%fpd !+ chsd_y()%dep_fp_m * sd_ch(ich)%chl
                end if
              end do
            end do
            !average the channel data by length
            do iord = 1, chcal(ireg)%ord_num
              if (chcal(ireg)%ord(iord)%nbyr > 0) then
                !! convert back to mm, t/ha, kg/ha
                if (chcal(ireg)%ord(iord)%length > 1.e-6) then
                  chcal(ireg)%ord(iord)%aa%chd = chcal(ireg)%ord(iord)%aa%chd / chcal(ireg)%ord(iord)%length
                  chcal(ireg)%ord(iord)%aa%chw = chcal(ireg)%ord(iord)%aa%chw / chcal(ireg)%ord(iord)%length
                  chcal(ireg)%ord(iord)%aa%hc = chcal(ireg)%ord(iord)%aa%hc / chcal(ireg)%ord(iord)%length
                  chcal(ireg)%ord(iord)%aa%fpd = chcal(ireg)%ord(iord)%aa%fpd / chcal(ireg)%ord(iord)%length
                end if
              end if
            end do
          end do    !reg
        end if

        do j = 1, sp_ob%hru_lte
          !! zero yearly balances after using them in soft data calibration (was in sd_hru_output)
          sdwb_y(j) = hwbz
          sdnb_y(j) = hnbz
          sdpw_y(j) = hpwz
          sdls_y(j) = hlsz
        end do
        
        do j = 1, sp_ob%chandeg
          !! zero yearly balances after using them in soft data calibration (was in sd_channel_output)
          chsd_y(ich) = chsdz
        end do
        
        do j = 1, mhru
          !! zero yearly balances after using them in soft data calibration (was in hru_output)
          hwb_y(j) = hwbz
          hnb_y(j) = hnbz
          hpw_y(j) = hpwz
          hls_y(j) = hlsz
          
          !! compute biological mixing at the end of every year
          !! if (biomix(j) > .001) call mgt_tillmix (j,biomix(j))
          if (hru(j)%hyd%biomix > .001)                              &
                   call mgt_newtillmix (j,hru(j)%hyd%biomix)

          !! update sequence number for year in rotation to that of
          !! the next year and reset sequence numbers for operations
          do ipl = 1, npl(j)
            idp = pcom(j)%plcur(ipl)%idplt
            if (idp > 0) then
              if (pldb(idp)%idc == 7) then
                pcom(j)%plcur(ipl)%curyr_mat =                            &
                    pcom(j)%plcur(ipl)%curyr_mat + 1
                pcom(j)%plcur(ipl)%curyr_mat =                            &
                    Min(pcom(j)%plcur(ipl)%curyr_mat,pldb(idp)%mat_yrs)
              end if
            end if
          end do

          !! update target nitrogen content of yield with data from
          !! year just simulated
          do ic = 1, mcr
            xx = Real(time%yrs)
            tnylda(j) = (tnylda(j) * xx + tnyld(j)) / (xx + 1.)
          end do

          if (time%idaf < 181) then
            isched = hru(j)%mgt_ops
            if (sched(isched)%num_ops > 0) then
            if (sched(isched)%mgt_ops(nop(j))%op /= "skip") then
              dorm_flag = 1
              ihru = j
              call mgt_operatn
              dorm_flag = 0
            end if
            nop(j) = nop(j) + 1
            if (nop(j) > sched(isched)%num_ops) then
              nop(j) = 1
            end if
            
            phubase(j) = 0.
            yr_skip(j) = 0
            end if
          end if
        end do

      !! update simulation year
      time%yrc = time%yrc + 1
      end do            !!     end annual loop

        !! average output for soft data calibration
        if (cal_codes%hyd_hru == 'y') then
          !average annual for hru calibration
          do ireg = 1, db_mx%lscal_reg
            do ilu = 1, lscal(ireg)%lum_num
              if (lscal(ireg)%lum(ilu)%nbyr > 0) then
                !! convert back to mm, t/ha, kg/ha
                lscal(ireg)%lum(ilu)%precip_aa = lscal(ireg)%lum(ilu)%precip_aa / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%precip_aa_sav = lscal(ireg)%lum(ilu)%precip_aa
                lscal(ireg)%lum(ilu)%aa%srr = lscal(ireg)%lum(ilu)%aa%srr / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%aa%lfr = lscal(ireg)%lum(ilu)%aa%lfr / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%aa%pcr = lscal(ireg)%lum(ilu)%aa%pcr / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%aa%etr = lscal(ireg)%lum(ilu)%aa%etr / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%aa%tfr = lscal(ireg)%lum(ilu)%aa%tfr / lscal(ireg)%lum(ilu)%nbyr
                lscal(ireg)%lum(ilu)%aa%sed = lscal(ireg)%lum(ilu)%aa%sed / lscal(ireg)%lum(ilu)%nbyr
                ! add nutrients
              end if
            end do
          end do
        end if
        
        if (cal_codes%hyd_hrul == 'y') then
          !average annual for hru_lte calibration
          do ireg = 1, db_mx%lscalt_reg
            do ilu = 1, lscalt(ireg)%lum_num
              if (lscalt(ireg)%lum(ilu)%nbyr > 0) then
                !! convert back to mm, t/ha, kg/ha
                lscalt(ireg)%lum(ilu)%precip_aa = lscalt(ireg)%lum(ilu)%precip_aa / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%precip_aa_sav = lscalt(ireg)%lum(ilu)%precip_aa
                lscalt(ireg)%lum(ilu)%aa%srr = lscalt(ireg)%lum(ilu)%aa%srr / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%aa%lfr = lscalt(ireg)%lum(ilu)%aa%lfr / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%aa%pcr = lscalt(ireg)%lum(ilu)%aa%pcr / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%aa%etr = lscalt(ireg)%lum(ilu)%aa%etr / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%aa%tfr = lscalt(ireg)%lum(ilu)%aa%tfr / lscalt(ireg)%lum(ilu)%nbyr
                lscalt(ireg)%lum(ilu)%aa%sed = lscalt(ireg)%lum(ilu)%aa%sed / lscalt(ireg)%lum(ilu)%nbyr
                ! add nutrients
              end if
            end do
          end do
        end if
            
        !! average output for soft data calibration
        if (cal_codes%plt == 'y') then
            
          !average annual for plant calibration
          do ireg = 1, db_mx%plcal_reg
            do ilu = 1, plcal(ireg)%lum_num
              if (plcal(ireg)%lum(ilu)%nbyr > 0) then
                !! convert back to mm, t/ha, kg/ha
                plcal(ireg)%lum(ilu)%precip_aa = plcal(ireg)%lum(ilu)%precip_aa / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%precip_aa_sav = plcal(ireg)%lum(ilu)%precip_aa
                plcal(ireg)%lum(ilu)%aa%yield = plcal(ireg)%lum(ilu)%aa%yield / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%aa%npp = plcal(ireg)%lum(ilu)%aa%npp / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%aa%lai_mx = plcal(ireg)%lum(ilu)%aa%lai_mx / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%aa%wstress = plcal(ireg)%lum(ilu)%aa%wstress / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%aa%astress = plcal(ireg)%lum(ilu)%aa%astress / plcal(ireg)%lum(ilu)%nbyr
                plcal(ireg)%lum(ilu)%aa%tstress = plcal(ireg)%lum(ilu)%aa%tstress / plcal(ireg)%lum(ilu)%nbyr
                ! add nutrients
              end if
            end do
          end do
        end if
        
        !! average channel output for soft data calibration
        if (cal_codes%chsed == 'y' .and. cal_codes%sed == 'n' .and. cal_codes%plt == 'n' .and. cal_codes%hyd_hru == 'n' .and. cal_codes%hyd_hrul == 'n') then
          do ireg = 1, db_mx%chcal_reg
            do ich = 1, chcal(ireg)%ord_num
              if (chcal(ireg)%ord(ich)%nbyr > 0) then
                !! soft data for w and d in mm/year (convert to m) -- hc soft and model in m -- fpd soft and model in mm
                chcal(ireg)%ord(ich)%aa%chd = 1000. * chcal(ireg)%ord(ich)%aa%chd / chcal(ireg)%ord(ich)%nbyr
                chcal(ireg)%ord(ich)%aa%chw = 1000. * chcal(ireg)%ord(ich)%aa%chw / chcal(ireg)%ord(ich)%nbyr
                chcal(ireg)%ord(ich)%aa%hc = chcal(ireg)%ord(ich)%aa%hc / chcal(ireg)%ord(ich)%nbyr
                chcal(ireg)%ord(ich)%aa%fpd = chcal(ireg)%ord(ich)%aa%fpd / chcal(ireg)%ord(ich)%nbyr
              end if
            end do
          end do
        end if

      return
 1234 format (1x,' Executing year/day ', 2i4)
      end subroutine time_control