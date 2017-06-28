     subroutine header_reservoir
    
     use basin_module
     use reservoir_module

    !! RESERVOIR
      if (pco%res%d == 'y' .and. sp_ob%res > 0 ) then
        open (2540,file="reservoir_day.txt",recl=800)
        write (9000,*) 'RES                 reservoir_day.txt'
        write (2540,*) res_hdr
        write (2540,*) res_hdr_unt
          if (pco%csvout == 'y') then
            open (2544,file="reservoir_day.csv",recl=800)
            write (2544,'(*(G0.3,:","))') res_hdr
            write (2544,'(*(G0.3,:","))') res_hdr_unt
            write (9000,*) 'RES                 reservoir_day.csv'
          end if
      end if
      
     if (pco%res%m == 'y' .and. sp_ob%res > 0 ) then
        open (2541,file="reservoir_mon.txt",recl=800)
        write (9000,*) 'RES                 reservoir_mon.txt'
        write (2541,*) res_hdr
        write (2541,*) res_hdr_unt
          if (pco%csvout == 'y') then
            open (2545,file="reservoir_mon.csv",recl=800)
            write (2545,'(*(G0.3,:","))') res_hdr
            write (2545,'(*(G0.3,:","))') res_hdr_unt
            write (2545,*) 'RES                 reservoir_mon.csv'
          end if
     end if
     
     if (pco%res%y == 'y' .and. sp_ob%res > 0 ) then
        open (2542,file="reservoir_yr.txt",recl=800)
        write (9000,*) 'RES                 reservoir_yr.txt'
        write (2542,*) res_hdr
        write (2542,*) res_hdr_unt
          if (pco%csvout == 'y') then
            open (2546,file="reservoir_yr.csv",recl=800)
            write (2546,'(*(G0.3,:","))') res_hdr
            write (2546,'(*(G0.3,:","))') res_hdr_unt
            write (9000,*) 'RES                 reservoir_yr.csv'
          end if
      end if
      
      if (pco%res%a == 'y' .and. sp_ob%res > 0) then
        open (2543,file="reservoir_aa.txt",recl = 800)
        write (2543,*) res_hdr
        write (2543,*) res_hdr_unt
        write (9000,*) 'RES                 reservoir_aa.txt'
          if (pco%csvout == 'y') then
            open (2547,file="reservoir_aa.csv",recl=800)
            write (2547,'(*(G0.3,:","))') res_hdr
            write (2547,'(*(G0.3,:","))') res_hdr_unt
            write (9000,*) 'RES                 reservoir_aa.csv'
          end if
      end if
    
      return
      end subroutine header_reservoir  