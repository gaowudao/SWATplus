      subroutine proc_res
    
      implicit none
    
      ! read reservoir data
      call res_read_init
      call res_read_hyd
      call res_read_sed
      call res_read_nut
      call res_read_pst
      call res_read_weir
      call res_read
      
      ! read wetland data
      call wet_read_hyd
      call wet_read
      
      call header_snutc
        
	  return
      
      end subroutine proc_res